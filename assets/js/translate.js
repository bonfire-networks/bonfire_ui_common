const CACHE_PREFIX = 'translate::';
const CACHE_TTL_DAYS = 7;

function createLogger(el) {
  const debugEnabled = el.dataset.translateDebug === 'true';
  const prefix = '[TranslateHook]';
  const log = (...args) => debugEnabled && console.log(prefix, ...args);
  return { log };
}

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
    localStorage.setItem(key, JSON.stringify({ value, timestamp: Date.now() }));
  } catch {
    // Quota exceeded or localStorage unavailable
  }
}

// Cache Translator instances by language pair to avoid redundant creation
const translatorCache = new Map();

async function getOrCreateTranslator(sourceLanguage, targetLanguage) {
  const key = `${sourceLanguage}::${targetLanguage}`;
  if (translatorCache.has(key)) return translatorCache.get(key);
  const translator = await Translator.create({ sourceLanguage, targetLanguage });
  translatorCache.set(key, translator);
  return translator;
}

let TranslateHooks = {};
TranslateHooks.Translate = {
  mounted() {
    this.logger = createLogger(this.el);
    this.logger.log('Hook mounting on element:', this.el.id);

    // Clean up any stale translated elements left from a previous hook lifecycle
    this.el.querySelectorAll('.translated-content').forEach(el => el.remove());

    this.clientBtn = this.el.querySelector('.translate-btn-client');
    this.serverBtn = this.el.querySelector('.translate-btn-server');
    this.translatables = this.el.querySelectorAll('.translatable:not(.translated-content)');
    this.isTranslated = false;
    this.translatedElements = new Map();
    this.activeBtn = null;

    this.sourceLanguage = this.el.dataset.translateFrom || null;
    this.targetLanguage = this.el.dataset.translateTo
      || navigator.language.split('-')[0];

    this.logger.log('Found elements:', {
      clientBtn: !!this.clientBtn,
      serverBtn: !!this.serverBtn,
      translatables: this.translatables.length
    });

    if (!this.clientBtn && !this.serverBtn) {
      this.logger.log('No translate buttons found, hook inactive');
      return;
    }

    if (this.translatables.length === 0) {
      this.logger.log('No translatable elements yet, will check again on click');
    }

    const serverAvailable = this.el.dataset.translateServerAvailable === 'true';

    // Register server push event handlers before async init
    this.handleEvent("translation_result", (data) => {
      if (data.id !== this.el.dataset.objectId) return;
      this.logger.log('Received server translation result:', data);
      this.applyServerTranslations(data.translations);
      this.isTranslated = true;
      if (this.activeBtn) this.activeBtn.classList.add('btn-active');
      this.updateActiveButtonText();
      this.setActiveButtonLoading(false);
    });

    this.handleEvent("translation_error", (data) => {
      if (data.id !== this.el.dataset.objectId) return;
      this.logger.log('Received server translation error:', data);
      this.showActiveButtonError();
      this.setActiveButtonLoading(false);
    });

    // Test Chrome API availability (async) then set up the right button
    this.detectAndSetup(serverAvailable);
  },

  async detectAndSetup(serverAvailable) {
    let chromeAvailable = false;
    if (('LanguageDetector' in self) && ('Translator' in self)) {
      try {
        const status = await LanguageDetector.availability();
        chromeAvailable = (status !== 'unavailable');
        if (!chromeAvailable) this.logger.log('Chrome Translation API not available:', status);
      } catch {
        this.logger.log('Chrome Translation API exists but is blocked by Permissions Policy');
      }
    }

    this.logger.log('Capabilities:', { chromeAvailable, serverAvailable });

    if (this.languagesMatch()) {
      this.logger.log('Source and target languages match, hiding all buttons');
    } else if (chromeAvailable && this.clientBtn) {
      this.activeBtn = this.clientBtn;
      this.clientBtn.style.display = '';
      this.logger.log('Showing client-side translate button (Chrome API)');
    } else if (serverAvailable && this.serverBtn) {
      this.activeBtn = this.serverBtn;
      this.serverBtn.style.display = '';
      this.logger.log('Showing server-side translate button');
    } else {
      this.logger.log('No translation capability available');
    }

    if (!this.activeBtn) return;

    this.updateActiveButtonText();

    if (this.activeBtn === this.clientBtn) {
      this.activeBtn.addEventListener('click', () => this.handleClientTranslateClick());
    } else if (this.activeBtn === this.serverBtn) {
      this.activeBtn.addEventListener('click', () => this.handleServerTranslateClick());
    }

    this.logger.log('Hook setup complete, active button:',
      this.activeBtn === this.clientBtn ? 'client' : 'server');
  },

  languagesMatch() {
    return this.sourceLanguage && this.sourceLanguage === this.targetLanguage;
  },

  updateActiveButtonText() {
    if (!this.activeBtn) return;
    const targetName = languageTagToHumanReadable(this.targetLanguage);
    this.activeBtn.textContent = this.isTranslated
      ? 'Show original'
      : `Translate to ${targetName}`;
  },

  setActiveButtonLoading(loading) {
    if (!this.activeBtn) return;
    this.activeBtn.classList.toggle('loading', loading);
    this.activeBtn.disabled = loading;
  },

  showActiveButtonError() {
    if (!this.activeBtn) return;
    this.activeBtn.classList.add('btn-error');
    setTimeout(() => this.activeBtn.classList.remove('btn-error'), 2000);
  },

  // --- Client-side (Chrome API) translation ---

  refreshTranslatables() {
    this.translatables = this.el.querySelectorAll('.translatable:not(.translated-content)');
    this.logger.log('Refreshed translatables:', this.translatables.length);
  },

  async handleClientTranslateClick() {
    this.logger.log('Client translate clicked, isTranslated:', this.isTranslated);
    if (this.isTranslated) {
      this.restoreOriginals();
      return;
    }
    this.refreshTranslatables();
    if (this.translatables.length === 0) {
      this.logger.log('No translatable elements found');
      return;
    }
    await this.performClientTranslation();
  },

  async performClientTranslation() {
    this.logger.log('Starting client-side translation:', {
      sourceLanguage: this.sourceLanguage || 'auto-detect',
      targetLanguage: this.targetLanguage
    });

    this.setActiveButtonLoading(true);
    try {
      const detector = this.sourceLanguage ? null : await this.createDetector();
      const results = await this.translateAll(detector);
      this.logger.log('Client translation results:', results);

      const entries = results
        .map(({ index, translation, error }) => {
          const element = this.translatables[index];
          if (error) {
            element.dataset.translateError = error;
            element.classList.add('translate-error');
            return null;
          }
          return { element, translation, useHTML: false };
        })
        .filter(Boolean);
      this.applyTranslations(entries);
      this.isTranslated = true;
      if (this.activeBtn) this.activeBtn.classList.add('btn-active');
      this.updateActiveButtonText();
      this.logger.log('Client translation complete');
    } catch (err) {
      this.logger.log('Client translation error:', err.name, err.message);
      this.showActiveButtonError();
    } finally {
      this.setActiveButtonLoading(false);
    }
  },

  async createDetector() {
    this.logger.log('Creating language detector...');
    const detector = await LanguageDetector.create();
    this.logger.log('Language detector created');
    return detector;
  },

  applyTranslations(entries) {
    entries.forEach(({ element, translation, useHTML }) => {
      if (!translation) return;

      // Remove any existing translated sibling to prevent duplicates
      const existingSibling = element.nextElementSibling;
      if (existingSibling && existingSibling.classList.contains('translated-content')) {
        existingSibling.remove();
      }

      element.hidden = true;
      element.classList.add('translated-hidden');

      const translatedEl = document.createElement(element.tagName);
      translatedEl.className = element.className + ' translated-content';

      if (useHTML) {
        translatedEl.innerHTML = translation;
      } else {
        translatedEl.textContent = translation;
      }

      element.insertAdjacentElement('afterend', translatedEl);

      const index = Array.from(this.translatables).indexOf(element);
      this.translatedElements.set(index, translatedEl);
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
      setCache(langKey, sourceLanguage);
    } else {
      this.logger.log(`Element ${index}: could not detect language`);
    }
    return sourceLanguage;
  },

  async doTranslate(index, text, sourceLanguage, textHash) {
    this.logger.log(`Element ${index}: checking availability for ${sourceLanguage} → ${this.targetLanguage}`);
    const availability = await Translator.availability({ sourceLanguage, targetLanguage: this.targetLanguage });
    this.logger.log(`Element ${index}: availability = "${availability}"`);

    if (availability === 'unavailable') {
      const sourceName = languageTagToHumanReadable(sourceLanguage);
      const targetName = languageTagToHumanReadable(this.targetLanguage);
      this.logger.log(`Element ${index}: language pair not supported`);
      return { index, translation: null, error: `${sourceName} → ${targetName} not supported` };
    }

    this.logger.log(`Element ${index}: getting translator...`);
    const translator = await getOrCreateTranslator(sourceLanguage, this.targetLanguage);
    this.logger.log(`Element ${index}: translating...`);
    const translation = await translator.translate(text);

    const translationKey = getTranslationCacheKey(textHash, this.targetLanguage);
    setCache(translationKey, translation);
    this.logger.log(`Element ${index}: translation cached (hash: ${textHash})`);
    return { index, translation, error: null };
  },

  // --- Server-side translation ---

  handleServerTranslateClick() {
    this.logger.log('Server translate clicked, isTranslated:', this.isTranslated);
    if (this.isTranslated) {
      this.restoreOriginals();
      return;
    }

    this.refreshTranslatables();
    this.setActiveButtonLoading(true);
    this.logger.log('Pushing server translate event for:', this.el.dataset.objectId);
    this.pushEvent("Bonfire.Translation:translate", {
      id: this.el.dataset.objectId,
      target_lang: this.targetLanguage,
      source_lang: this.sourceLanguage
    });
    this.logger.log('Pushed server translate event for object:', this.el.dataset.objectId);
  },

  applyServerTranslations(translations) {
    this.logger.log('Applying server translations:', Object.keys(translations));

    const entries = Array.from(this.translatables).map((el, index) => {
      const role = el.dataset.role
        || el.closest('[data-role]')?.dataset.role;
      let fieldName = null;

      if (role === 'name') fieldName = 'name';
      else if (role === 'summary' || role === 'cw') fieldName = 'summary';
      else if (role === 'html_body' || el.dataset.id === 'object_body' || el.classList.contains('object_body')) fieldName = 'html_body';
      else {
        console.warn(`[TranslateHook] Unmapped translatable role "${role}", skipping element`);
        return { element: el, translation: null, useHTML: false };
      }

      const translation = translations[fieldName];
      this.logger.log(`Element ${index} (role=${role}, field=${fieldName}):`, translation ? 'has translation' : 'no translation');

      return { element: el, translation, useHTML: fieldName === 'html_body' };
    });

    this.applyTranslations(entries);
  },

  // --- Shared: restore originals ---

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
    if (this.activeBtn) this.activeBtn.classList.remove('btn-active');
    this.updateActiveButtonText();
  },

  updated() {
    // After LiveView patches the DOM, re-query translatables (excluding translated content)
    // to keep references in sync, but preserve translation state
    this.translatables = this.el.querySelectorAll('.translatable:not(.translated-content)');
  },

  destroyed() {
    // Clean up translated DOM elements to prevent leaks
    if (this.translatedElements) {
      this.translatedElements.forEach(el => el.remove());
      this.translatedElements.clear();
    }
    // Also clean any orphaned translated elements within this hook's element
    this.el.querySelectorAll('.translated-content').forEach(el => el.remove());
    this.activeBtn = null;
    this.translatables = null;
  }
};

export { TranslateHooks };
