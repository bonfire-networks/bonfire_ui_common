let InputSelectHooks = {};

import Tagify from '@yaireo/tagify'

InputSelectHooks.InputOrSelectOne = {

    initInputOrSelectOne() {
        let $input = this.el.querySelector("input.tagify"),
            $select = this.el.querySelector("select.tagify");

        let id = this.el.id || $input.id;

        let userCanInput = true;
        if ($input.dataset.userInput) {
            userCanInput = $input.dataset.userInput
        }

        let phxAutocomplete = false;
        if ($select.dataset.phxAutocomplete) {
            phxAutocomplete = $select.dataset.phxAutocomplete
        }
        // console.log(phxAutocomplete)

        var suggestions = [] // inputElm.value.trim().split(/\s*,\s*/) // TODO: create array of values from initial input value(s)?

        Array.from($select.options).forEach(opt => {
            var entry = {};
            entry.value = opt.value;
            entry.text = opt.text;
            suggestions.push(entry);
        });
        console.log("suggestions: ", suggestions)

        const suggestionItemTemplate = function (tagData) {
            return `
            <div ${this.getAttributes(tagData)}
                class='tagify__dropdown__item ${tagData.class ? tagData.class : ""}'
                tabindex="0"
                role="option">
                <span>${tagData.text}</span>
            </div>
            `
        }

        const tagTemplate = function (tagData) {
            return `
            <tag 
                contenteditable='false'
                spellcheck='false'
                tabIndex="-1"
                class="tagify__tag ${tagData.class ? tagData.class : ""}"
                ${this.getAttributes(tagData)}>
                <x title='' class='tagify__tag__removeBtn' role='button' aria-label='remove tag'></x>
                <div>
                    <span class='tagify__tag-text'>${tagData.text}</span>
                </div>
            </tag>
            `
        }

        const tagify = new Tagify($input, {
            id: this.el.id,
            userInput: userCanInput === 'false' ? false : true,
            whitelist: suggestions,
            enforceWhitelist: true, // only tags from suggestions list are valid?
            keepInvalidTags: true, // keep tags that aren't in the suggestion list anyway?
            originalInputValueFormat: valuesArr => valuesArr.map(item => item.value).join(','),
            callbacks: {
                "input": (e) => {
                    if (phxAutocomplete && e.detail.value) {
                        // console.log("tagify_autocomplete: ", e.detail.value);
                        tagify.loading(true) // show the loader animation
                        this.pushEventTo("#" + id, phxAutocomplete, { input: e.detail.value })
                        tagify.dropdown.show(e.detail.value); // render the suggestions dropdown.
                    }
                },
                "add": (e) => {
                    if (e.detail.data) {
                        this.pushEventTo("#" + id, "tagify_add", { id: e.detail.data.value, name: e.detail.data.text })
                    }
                },
                "remove": (e) => {
                    if (e.detail.data) {
                        this.pushEventTo("#" + id, "tagify_remove", { id: e.detail.data.value })
                    }
                }
            },
            dropdown: {
                maxItems: 50,           // <- maximum allowed rendered suggestions
                classname: "InputOrSelectOne-dropdown", // <- custom classname(s) for the dropdown
                enabled: 0,             // <- show suggestions on focus
                closeOnSelect: true,    // <- do not hide the suggestions dropdown once an item has been selected
                searchKeys: ['text']  // which keys to search for suggestions when typing
            },
            // blacklist: ['foo', 'bar'],
            templates: {
                // wrapper: wrapperTemplate,
                dropdownItem: suggestionItemTemplate,
                tag: tagTemplate
            },
        })

        if (window.InputOrSelectOnes == undefined) {
            window.InputOrSelectOnes = {};
        }

        window.InputOrSelectOnes[this.el.id] = tagify;
    },


    mounted() {
        this.initInputOrSelectOne();
    },

    updated() {
        console.log("input_select updated")
        // const tagify = window.InputOrSelectOnes[this.el.id]; // FIXME: doesn't work because we can't have phx-ignore and also update the input value in LV
        // tagify.loadOriginalValues();
        // tagify.loading(false) // hide the loader animation
        
        // FIXME: not ideal to completely re-initialise tagify here rather than update the values
        this.initInputOrSelectOne();
    },
    // selected(hook, event) {
    //     let id = event.params.data.id;
    //     hook.pushEvent("country_selected", { country: id })
    // }
}

export { InputSelectHooks }