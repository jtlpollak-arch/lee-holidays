function runSplashScreen(parentSelector, clientName, onCompleteCallback) {
    const parent = document.querySelector(parentSelector);
    if (!parent) return;

    parent.style.position = 'relative';

    const selectors = ['.lee-key-container-svg', '.lee-course-svg', '.lee-safe-home-svg', '.lee-handshake-svg', '.logo-wrapper'];
    const wrappers = [];

    const overlay = document.createElement('div');
    overlay.className = 'splash-overlay';
    parent.appendChild(overlay);

    const nameEl = document.createElement('div');
    nameEl.className = 'splash-name-center';
    nameEl.innerHTML = `${clientName}<br>מזל-טוב!`;
    overlay.appendChild(nameEl);

    selectors.forEach((s, index) => {
        const el = document.querySelector(s);
        if (!el) return;

        const svg = el.tagName.toLowerCase() === 'svg' ? el : el.querySelector('svg');
        if (svg) {
            const parentRect = parent.getBoundingClientRect();
            const elRect = el.getBoundingClientRect();
            
            const startX = elRect.left - parentRect.left;
            const startY = elRect.top - parentRect.top;
            
            const wrapper = document.createElement('div');
            wrapper.className = 'splash-icon-wrapper';
            wrapper.style.left = `${startX}px`;
            wrapper.style.top = `${startY}px`;
            wrapper.style.width = `${elRect.width}px`;
            wrapper.style.height = `${elRect.height}px`;
            
            const angle = (index / selectors.length) * 360;
            wrapper.style.setProperty('--orbit-angle', `${angle}deg`);
            wrapper.style.setProperty('--delay', `${index * 0.1}s`);
            
            const clone = svg.cloneNode(true);
            clone.removeAttribute('class');
            clone.removeAttribute('style');
            clone.style.width = '100%';
            clone.style.height = '100%';
            
            wrapper.appendChild(clone);
            overlay.appendChild(wrapper);
            wrappers.push(wrapper);
        }
    });

    setTimeout(() => {
        wrappers.forEach(w => w.classList.add('wow-effect'));
        nameEl.classList.add('reveal-name');
    }, 1000);

    setTimeout(() => {
        overlay.classList.add('fade-out');
    }, 3500);

    setTimeout(() => {
        overlay.remove();
        if (typeof onCompleteCallback === 'function') onCompleteCallback();
    }, 3500);
}