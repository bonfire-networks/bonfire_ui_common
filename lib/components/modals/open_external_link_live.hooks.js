
let LinksClickPrompt = {
	mounted() {
		this.el.addEventListener("click", e => {
			const link = e.target.closest('a');
			if (!link) return;

			e.preventDefault();
			const url = window.prompt("Confirm or edit URL to follow:", link.href);

			if (url) {
				window.location.href = url;
			}
		});
	}
};

let LinksDangerModal = {
	mounted() {
		this.el.addEventListener("click", e => {
			const link = e.target.closest('a');
			if (!link) return;
			
			const url = link.href;

			if (url && url.indexOf("/") != 0) {
				e.preventDefault();
				this.pushEvent("Bonfire.UI.Common.ReusableModalLive:prompt_external_link", { url: url })
			}
		});
	}
};

export { LinksClickPrompt, LinksDangerModal };
