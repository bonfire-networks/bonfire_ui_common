function date_future(days) {
	let date = new Date();
	// Set expiry to X days
	date.setDate(date.getDate() + days);
	return date.toGMTString();
}

export default {
	mounted() {
		// Set cookie when locale is changed
		this.el.addEventListener('change', (e) => {
			console.log('Locale changed to:', e.target.value);
			document.cookie = `locale=${e.target.value}; path=/; expires=${date_future(90)}`;
			// The form will trigger the LiveView event automatically via phx-change
			// Just reload after a short delay to ensure the settings are saved and cookie is read
			setTimeout(() => {
				window.location.reload();
			}, 500);
		});
	},
	
	destroyed() {
		// Keep this for backward compatibility
		console.log(this.el.value);
		document.cookie = `locale=${this.el.value}; path=/; expires=${date_future(90)}`;
		// Cookie.set("locale", this.el.value)
	},
};
