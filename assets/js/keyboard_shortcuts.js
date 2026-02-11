let KeyboardShortcutHooks = {};

KeyboardShortcutHooks.KeyboardShortcuts = {
	mounted() {
		this.shortcuts = {
			n: {
				description: "Open composer",
				action: () => {
					const btn = document.getElementById("main_smart_input_button");
					if (btn && !btn.disabled) btn.click();
				},
			},
			"-": {
				description: "Minimize composer",
				action: () => {
					this._minimizeComposer();
				},
			},
			Escape: {
				description: "Unfocus / close composer",
				allowInInput: true,
				action: () => {
					const active = document.activeElement;
					if (active && active !== document.body) {
						active.blur();
						return;
					}
					this._minimizeComposer();
				},
			},
			"?": {
				description: "Show keyboard shortcuts",
				action: () => {
					const modal = document.getElementById(
						"keyboard-shortcuts-help",
					);
					if (modal) modal.showModal();
				},
			},
		};

		this._keydownHandler = (e) => {
			if (e.ctrlKey || e.metaKey || e.altKey) return;
			if (e.shiftKey && e.key !== "?") return;

			const shortcut = this.shortcuts[e.key];
			if (!shortcut) return;

			if (!shortcut.allowInInput && this._isInputFocused()) return;

			shortcut.action(e);
		};
		window.addEventListener("keydown", this._keydownHandler);
	},

	destroyed() {
		if (this._keydownHandler) {
			window.removeEventListener("keydown", this._keydownHandler);
		}
	},

	_minimizeComposer() {
		const btn = document.getElementById("minimize_composer_button");
		if (btn) {
			const phxClick = btn.getAttribute("phx-click");
			if (phxClick && window.liveSocket) {
				window.liveSocket.execJS(btn, phxClick);
			}
		}
	},

	_isInputFocused() {
		const el = document.activeElement;
		if (!el || el === document.body) return false;

		const tag = el.tagName.toLowerCase();
		if (tag === "input" || tag === "textarea" || tag === "select")
			return true;
		if (el.isContentEditable) return true;
		if (el.closest("[contenteditable='true']")) return true;

		return false;
	},
};

export { KeyboardShortcutHooks };
