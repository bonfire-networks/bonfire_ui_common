// usage: openIframeModal("https://example.com")

function appendToBody(el) {
  if (document.body) document.body.appendChild(el);
  else document.documentElement.appendChild(el);
}

function iframeModal(url, title = "Modal", btnText = "Open") {
  if (window.__iframeModalInjected) return;
  window.__iframeModalInjected = true;

  // ---------- styles ----------
  const style = document.createElement("style");
  style.textContent = `
    #iframe-launch-btn {
      position: fixed;
      bottom: 20px;
      right: 20px;
      z-index: 999999;
      padding: 10px 14px;
      border-radius: 999px;
      border: none;
      background: #111;
      color: #fff;
      cursor: pointer;
      font-size: 14px;
      box-shadow: 0 4px 12px rgba(0,0,0,.3);
    }

    #iframe-modal {
      position: fixed;
      width: 600px;
      height: 400px;
      bottom: 80px;
      right: 20px;
      background: #fff;
      border-radius: 8px;
      box-shadow: 0 10px 30px rgba(0,0,0,.4);
      z-index: 999998;
      display: none;
      resize: both;
      overflow: hidden;
    }

    #iframe-header {
      height: 36px;
      background: #222;
      color: #fff;
      cursor: move;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 8px;
      font-size: 13px;
    }

    #iframe-header button {
      background: none;
      border: none;
      color: #fff;
      cursor: pointer;
      font-size: 14px;
      margin-left: 6px;
    }

    #iframe-body {
      width: 100%;
      height: calc(100% - 36px);
    }

    #iframe-body iframe {
      width: 100%;
      height: 100%;
      border: none;
    }

    #iframe-modal.minimized {
      height: 36px !important;
      resize: none;
    }

    #iframe-modal.minimized #iframe-body {
      display: none;
    }
  `;
  
  (document.head || document.documentElement).appendChild(style);

  // ---------- button ----------
  const launchBtn = document.createElement("button");
  launchBtn.id = "iframe-launch-btn";
  launchBtn.textContent = btnText;
  appendToBody(launchBtn);

  // ---------- modal ----------
  const modal = document.createElement("div");
  modal.id = "iframe-modal";
  modal.innerHTML = `
    <div id="iframe-header">
      <span>`+title+`</span>
      <div>
        <button id="minimize-btn">—</button>
        <button id="close-btn">✕</button>
      </div>
    </div>
    <div id="iframe-body">
      <iframe></iframe>
    </div>
  `;
  appendToBody(modal);

  const iframe = modal.querySelector("iframe");
  const header = modal.querySelector("#iframe-header");
  const closeBtn = modal.querySelector("#close-btn");
  const minimizeBtn = modal.querySelector("#minimize-btn");

  // ---------- open function ----------
  window.openIframeModal = function () {
    iframe.src = url;
    modal.style.display = "block";
    modal.classList.remove("minimized");
  };

  launchBtn.onclick = () => {
    window.openIframeModal(url);
  };

  closeBtn.onclick = () => {
    modal.style.display = "none";
    iframe.src = "";
  };

  minimizeBtn.onclick = () => {
    modal.classList.toggle("minimized");
  };

  // ---------- drag logic ----------
  let isDragging = false;
  let startX, startY, startLeft, startTop;

  header.addEventListener("mousedown", (e) => {
    isDragging = true;
    startX = e.clientX;
    startY = e.clientY;
    const rect = modal.getBoundingClientRect();
    startLeft = rect.left;
    startTop = rect.top;
    document.body.style.userSelect = "none";
  });

  document.addEventListener("mousemove", (e) => {
    if (!isDragging) return;
    modal.style.left = startLeft + (e.clientX - startX) + "px";
    modal.style.top = startTop + (e.clientY - startY) + "px";
    modal.style.right = "auto";
    modal.style.bottom = "auto";
  });

  document.addEventListener("mouseup", () => {
    isDragging = false;
    document.body.style.userSelect = "";
  });

  return modal;
}