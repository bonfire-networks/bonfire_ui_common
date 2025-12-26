(async () => {
    // In Tauri, you can use the asset protocol to load local files
    const wasmPath = 'local://assets/openmls/openmls_wasm_bg.wasm';
    const jsModule = await import("local://assets/openmls/openmls_wasm.js");

    // Initialize with local WASM
    await jsModule.default(wasmPath);

    // Expose to global scope for your web app
    window.myWasmModule = jsModule;
})();
