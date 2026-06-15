/**
 * splash-screen.js
 */

function runSplashScreen(parentSelector, clientName, onCompleteCallback) {
    const parent = document.querySelector(parentSelector);
    if (!parent) return;

    // 1. "צילום" המיקום של הקונטיינר
    const rect = parent.getBoundingClientRect();

    // 2. יצירת האפקט
    const overlay = parent.cloneNode(true);
    overlay.removeAttribute('id');
    overlay.innerHTML = '';
    
    // ניקוי מוחלט של סגנונות ירושים מהבית
    overlay.className = 'splash-overlay'; 
    overlay.style.position = 'fixed';
    overlay.style.top = rect.top + 'px';
    overlay.style.left = rect.left + 'px';
    overlay.style.width = rect.width + 'px';
    overlay.style.height = rect.height + 'px';
    overlay.style.boxShadow = 'none';
    overlay.style.border = 'none';
    overlay.style.margin = '0';
    overlay.style.padding = '0';
    overlay.style.backgroundColor = 'transparent';
    overlay.style.overflow = 'visible';

    document.body.appendChild(overlay);

    // 3. הוספת השם
    const nameEl = document.createElement('div');
    nameEl.className = 'splash-name-center';
    nameEl.textContent = clientName;
    overlay.appendChild(nameEl);

    // 4. הוספת האייקונים
    const selectors = [
        '.lee-key-container-svg', '.lee-course-svg', 
        '.lee-safe-home-svg', '.lee-handshake-svg', '.logo-wrapper'
    ];
    
    const wrappers = [];
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    const radius = Math.min(rect.width, rect.height) / 3;

    selectors.forEach((s, i) => {
        const el = document.querySelector(s);
        if (el) {
            const svg = el.tagName.toLowerCase() === 'svg' ? el : el.querySelector('svg');
            if (svg) {
                const clone = svg.cloneNode(true);
                clone.classList.add('splash-icon-clean');
                
                const wrapper = document.createElement('div');
                wrapper.className = 'splash-icon-wrapper';
                wrapper.appendChild(clone);
                
                // חישוב מיקום מעגלי סביב המרכז
                const angle = (i / selectors.length) * Math.PI * 2;
                wrapper.style.left = `${centerX + Math.cos(angle) * radius - 20}px`;
                wrapper.style.top = `${centerY + Math.sin(angle) * radius - 20}px`;
                
                overlay.appendChild(wrapper);
                wrappers.push({ wrapper, clone });
            }
        }
    });

    // 5. הרצת האנימציה
    wrappers.forEach((w, i) => {
        setTimeout(() => w.clone.classList.add('ignited'), 300 * (i + 1));
    });

    // שלב ההתכנסות
    setTimeout(() => {
        wrappers.forEach(w => {
            w.wrapper.style.left = `${centerX - 20}px`;
            w.wrapper.style.top = `${centerY - 20}px`;
            w.wrapper.style.transform = 'scale(0.2)';
            w.wrapper.style.opacity = '0';
        });
        overlay.classList.add('fade-out');
    }, 50000);

    // ניקוי סופי
    setTimeout(() => {
        overlay.remove();
        if (typeof onCompleteCallback === 'function') onCompleteCallback();
    }, 60000);
}