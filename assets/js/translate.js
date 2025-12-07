// TranslateHook: A LiveView hook to provide translation functionality
// Uses the browser's built-in LanguageDetector and Translator APIs if available
// Falls back to server event or hides button if unsupported

// Example usage:
/*
<div phx-hook="Translate" id="post-123-translate" data-translate-debug="true" data-translate-from="fr" data-translate-to="en" data-translate-fallback-event="translate_fallback">
    <p class="translatable">Bonjour le monde!</p>
    <p class="translatable">Comment allez-vous aujourd'hui?</p>

    <!-- Optional: language selector -->
    <select class="translate-lang-select select select-sm">
        <option value="">Auto (browser)</option>
        <option value="en">English</option>
        <option value="es">Spanish</option>
        <option value="fr">French</option>
    </select>

    <button class="translate-btn btn btn-sm btn-ghost" phx-update="ignore">
        <span class="loading-spinner"></span>
        Translate
    </button>
</div>
*/

// Cache prefix and TTL for localStorage
const CACHE_PREFIX = 'translate::';
const CACHE_TTL_DAYS = 7;

// Debug logger - only logs when debug mode is enabled
function createLogger(el) {
  const debugEnabled = el.dataset.translateDebug === 'true';
  const prefix = '[TranslateHook]';
  
  const log = (...args) => debugEnabled && console.log(prefix, ...args);
  
  return { log };
}

// Fast djb2 hash - good distribution, low collisions, not crypto-safe 
function hashString(str) {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash) ^ str.charCodeAt(i);
  }
  return (hash >>> 0).toString(16);
}

function languageTagToHumanReadable(languageTag, targetLanguage = 'en') {
  try {
    const displayNames = new Intl.DisplayNames([targetLanguage], { type: 'language' });
    return displayNames.of(languageTag);
  } catch {
    return languageTag;
  }
}

function getTranslationCacheKey(textHash, targetLang) {
  return `${CACHE_PREFIX}t::${targetLang}::${textHash}`;
}

function getLanguageCacheKey(textHash) {
  return `${CACHE_PREFIX}lang::${textHash}`;
}

function getCached(key) {
  try {
    const item = localStorage.getItem(key);
    if (!item) return null;
    
    const { value, timestamp } = JSON.parse(item);
    const age = Date.now() - timestamp;
    const maxAge = CACHE_TTL_DAYS * 24 * 60 * 60 * 1000;
    
    if (age > maxAge) {
      localStorage.removeItem(key);
      return null;
    }
    
    return value;
  } catch {
    return null;
  }
}

function setCache(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify({
      value,
      timestamp: Date.now()
    }));
  } catch {
    // Quota exceeded or localStorage unavailable, ignore
  }
}

let TranslateHooks = {};
TranslateHooks.Translate = {
  mounted() {
    this.logger = createLogger(this.el);
    this.logger.log('Hook mounting on element:', this.el.id);
    
    this.btn = this.el.querySelector('.translate-btn');
    this.translatables = this.el.querySelectorAll('.translatable');
    this.langSelect = this.el.querySelector('.translate-lang-select');
    this.isTranslated = false;
    this.translatedElements = new Map();
    
    // Cache language values once on mount
    this.sourceLanguage = this.el.dataset.translateFrom || null;
    this.targetLanguage = this.langSelect?.value 
      || this.el.dataset.translateTo 
      || navigator.language.split('-')[0];
    
    this.logger.log('Found elements:', {
      button: !!this.btn,
      translatables: this.translatables.length,
      langSelect: !!this.langSelect
    });
    
    if (!this.btn || this.translatables.length === 0) {
      this.logger.log('Missing required elements, hook inactive');
      return;
    }

    // Check if translation is available and should be shown
    const hideReason = this.getHideReason();
    if (hideReason) {
      this.hideButton(hideReason);
      return;
    }

    this.logger.log('Found', this.translatables.length, 'translatable elements');

    if (this.langSelect) {
      this.langSelect.addEventListener('change', () => {
        this.targetLanguage = this.langSelect.value;
        // this.updateButtonText();
        // this.updateButtonVisibility();
      });
    } else {
      this.updateButtonText();
    }

    this.btn.addEventListener('click', () => this.handleTranslateClick());
    this.logger.log('Hook mounted successfully');
  },

  // Returns reason to hide button, or null if button should be visible
  getHideReason() {
    const hasLanguageDetector = 'LanguageDetector' in self;
    const hasTranslator = 'Translator' in self;
    
    this.logger.log('API availability:', { hasLanguageDetector, hasTranslator });
    
    if (!hasLanguageDetector || !hasTranslator) {
      return 'apis_unavailable';
    }
    
    if (this.languagesMatch()) {
      return 'same_language';
    }
    
    return null;
  },

  // Check if source and target languages match (only when source is explicit)
  languagesMatch() {
    return this.sourceLanguage && this.sourceLanguage === this.targetLanguage;
  },

  hideButton(reason) {
    const fallbackEvent = this.el.dataset.translateFallbackEvent;
    
    if (reason === 'apis_unavailable' && fallbackEvent) {
      this.logger.log('APIs unavailable, pushing fallback event:', fallbackEvent);
      this.pushEvent(fallbackEvent, { reason: 'unsupported' });
    } else {
      const messages = {
        apis_unavailable: 'APIs unavailable, hiding translate button',
        same_language: `Source and target languages match, hiding button`
      };
      this.logger.log(messages[reason] || `Hiding button: ${reason}`);
      this.btn.style.display = 'none';
    }
  },

  updateButtonVisibility() {
    if (this.languagesMatch()) {
      this.logger.log('Source and target languages now match, hiding button');
      this.btn.style.display = 'none';
    } else {
      this.btn.style.display = '';
    }
  },

  updateButtonText() {
    if (this.langSelect) return;
    
    const targetName = languageTagToHumanReadable(this.targetLanguage);
    this.btn.textContent = this.isTranslated 
      ? 'Show original' 
      : `Translate to ${targetName}`;
  },

  async handleTranslateClick() {
    this.logger.log('Translate button clicked, isTranslated:', this.isTranslated);
    
    if (this.isTranslated) {
      this.restoreOriginals();
      return;
    }

    await this.performTranslation();
  },

  restoreOriginals() {
    this.logger.log('Toggling back to original content');
    this.translatables.forEach((el, index) => {
      el.hidden = false;
      el.classList.remove('translated-hidden');
      
      const translatedEl = this.translatedElements.get(index);
      if (translatedEl) {
        translatedEl.remove();
      }
    });
    this.translatedElements.clear();
    this.isTranslated = false;
    this.btn.classList.remove('btn-active');
    this.updateButtonText();
  },

  async performTranslation() {
    this.logger.log('Starting translation:', { 
      sourceLanguage: this.sourceLanguage || 'auto-detect', 
      targetLanguage: this.targetLanguage 
    });
    
    this.setButtonLoading(true);

    try {
      const detector = this.sourceLanguage ? null : await this.createDetector();
      const results = await this.translateAll(detector);
      this.logger.log('Translation results:', results);
      
      this.applyTranslations(results);
      this.isTranslated = true;
      this.btn.classList.add('btn-active');
      this.updateButtonText();
      this.logger.log('Translation complete');
    } catch (err) {
      this.logger.log('Translation error:', err.name, err.message);
      this.showButtonError();
    } finally {
      this.setButtonLoading(false);
    }
  },

  async createDetector() {
    this.logger.log('Creating language detector...');
    const detector = await LanguageDetector.create();
    this.logger.log('Language detector created');
    return detector;
  },

  setButtonLoading(loading) {
    this.btn.classList.toggle('loading', loading);
    this.btn.disabled = loading;
  },

  showButtonError() {
    this.btn.classList.add('btn-error');
    setTimeout(() => this.btn.classList.remove('btn-error'), 2000);
  },

  applyTranslations(results) {
    results.forEach(({ index, translation, error }) => {
      const originalEl = this.translatables[index];
      
      if (translation) {
        originalEl.hidden = true;
        originalEl.classList.add('translated-hidden');
        
        const translatedEl = document.createElement(originalEl.tagName);
        translatedEl.className = originalEl.className + ' translated-content';
        translatedEl.textContent = translation;
        originalEl.insertAdjacentElement('afterend', translatedEl);
        
        this.translatedElements.set(index, translatedEl);
      } else if (error) {
        originalEl.dataset.translateError = error;
        originalEl.classList.add('translate-error');
      }
    });
  },

  async translateAll(detector) {
    const results = [];
    
    for (let index = 0; index < this.translatables.length; index++) {
      const result = await this.translateElement(index, detector);
      results.push(result);
    }

    return results;
  },

  async translateElement(index, detector) {
    const originalText = this.translatables[index].textContent.trim();
    
    if (!originalText) {
      this.logger.log(`Element ${index}: empty, skipping`);
      return { index, translation: '', error: null };
    }

    const textHash = hashString(originalText);
    const translationKey = getTranslationCacheKey(textHash, this.targetLanguage);
    const cached = getCached(translationKey);
    if (cached) {
      this.logger.log(`Element ${index}: translation cache hit`);
      return { index, translation: cached, error: null };
    }

    try { 
      const sourceLanguage = await this.resolveSourceLanguage(index, detector, originalText, textHash);
      
      if (!sourceLanguage) {
        return { index, translation: null, error: 'Could not detect language' };
      }

      // Skip if already in target language
      if (sourceLanguage === this.targetLanguage) {
        this.logger.log(`Element ${index}: already in target language, skipping`);
        return { index, translation: originalText, error: null };
      }

      return await this.doTranslate(index, originalText, sourceLanguage, textHash);
    } catch (err) {
      this.logger.log(`Element ${index}: translation failed:`, err);
      return { index, translation: null, error: 'Translation failed' };
    }
  },

  async resolveSourceLanguage(index, detector, text, textHash) {
    if (this.sourceLanguage) {
      this.logger.log(`Element ${index}: using provided source language "${this.sourceLanguage}"`);
      return this.sourceLanguage;
    }

    // Check language detection cache
    const langKey = getLanguageCacheKey(textHash);
    const cachedLang = getCached(langKey);
    if (cachedLang) {
      this.logger.log(`Element ${index}: language cache hit "${cachedLang}"`);
      return cachedLang;
    }

    this.logger.log(`Element ${index}: detecting language...`);
    const detections = await detector.detect(text);
    const sourceLanguage = detections[0]?.detectedLanguage;
    const confidence = detections[0]?.confidence;
    
    if (sourceLanguage) {
      this.logger.log(`Element ${index}: detected "${sourceLanguage}" (${(confidence * 100).toFixed(1)}% confidence)`);
      // Cache the detected language
      setCache(langKey, sourceLanguage);
    } else {
      this.logger.log(`Element ${index}: could not detect language`);
    }
    
    return sourceLanguage;
  },

  async doTranslate(index, text, sourceLanguage, textHash) {
    this.logger.log(`Element ${index}: checking translator availability for ${sourceLanguage} → ${this.targetLanguage}`);
    const availability = await Translator.availability({ sourceLanguage, targetLanguage: this.targetLanguage });
    this.logger.log(`Element ${index}: availability = "${availability}"`);
    
    if (availability === 'unavailable') {
      const sourceName = languageTagToHumanReadable(sourceLanguage);
      const targetName = languageTagToHumanReadable(this.targetLanguage);
      this.logger.log(`Element ${index}: language pair not supported`);
      return { 
        index, 
        translation: null, 
        error: `${sourceName} → ${targetName} not supported` 
      };
    }

    this.logger.log(`Element ${index}: creating translator...`);
    const translator = await Translator.create({ sourceLanguage, targetLanguage: this.targetLanguage });
    
    this.logger.log(`Element ${index}: translating...`);
    const translation = await translator.translate(text);
    
    // Cache with hash key
    const translationKey = getTranslationCacheKey(textHash, this.targetLanguage);
    setCache(translationKey, translation);
    this.logger.log(`Element ${index}: translation cached (hash: ${textHash})`);
    
    return { index, translation, error: null };
  }
};

export { TranslateHooks };
