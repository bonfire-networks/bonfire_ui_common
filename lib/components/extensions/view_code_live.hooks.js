function update_hash() {
	let hash = location.hash;
	// clear existing highlighted lines
	Array.from(document.getElementsByClassName("highlighted")).forEach(
		function (n, i) {
			n.classList.remove("highlighted");
		},
	);

	if (hash.startsWith("#L")) {
		let id = hash.slice(1);
		let line = document.getElementById(id);
		if (line) {
			line.classList.add("highlighted");
		}
	}
}

let loadHash = {
	mounted() {
		let loc = window.location;
		let url =
			loc.protocol +
			"//" +
			loc.host +
			loc.pathname +
			"#L" +
			this.el.dataset.lineNumber;
		history.pushState(history.state, document.title, url);
		update_hash();

		window.onhashchange = function () {
			update_hash();
		};
	},
};

let updateHash = {
	mounted() {
		this.el.addEventListener("click", (e) => {
			let loc = window.location;
			let url =
				loc.protocol +
				"//" +
				loc.host +
				loc.pathname +
				"#L" +
				this.el.dataset.lineNumber;
			history.pushState(history.state, document.title, url);
			update_hash();
			e.preventDefault();
		});
	},
};

export { loadHash, updateHash };
