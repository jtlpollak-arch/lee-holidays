/**
 * splash-screen.js - FULL FILE - DO NOT PRUNE
 */

function runSplashScreen(clientName, onCompleteCallback) {
    const overlay = document.createElement('div');
    overlay.className = 'splash-overlay';
    document.body.appendChild(overlay);

    const nameEl = document.createElement('div');
    nameEl.className = 'splash-name-center';
    nameEl.textContent = clientName;
    overlay.appendChild(nameEl);

    const selectors = [
        '.lee-key-container-svg', 
        '.lee-course-svg', 
        '.lee-safe-home-svg', 
        '.lee-handshake-svg', 
        '.logo-wrapper'
    ];
    
    const wrappers = [];
    const radius = 220;
    const centerX = window.innerWidth / 2;
    const centerY = window.innerHeight / 2;

    selectors.forEach((s, i) => {
        const el = document.querySelector(s);
        if (el) {
            const svg = el.tagName.toLowerCase() === 'svg' ? el : el.querySelector('svg');
            if (svg) {
                // 1. יצירת עותק נקי
                const clone = svg.cloneNode(true);
                
                // 2. ניקוי רדיקלי - הסרת כל עיצוב קיים
                clone.removeAttribute('style');
                clone.removeAttribute('class');
                clone.style.cssText = "";
                clone.classList.add('splash-icon-clean');
                
                // 3. יצירת עטיפה
                const wrapper = document.createElement('div');
                wrapper.className = 'splash-icon-wrapper';
                wrapper.appendChild(clone);
                
                const angle = (i / selectors.length) * Math.PI * 2;
                const x = Math.cos(angle) * radius;
                const y = Math.sin(angle) * radius;
                
                wrapper.style.transform = `translate(${x}px, ${y}px)`;
                
                overlay.appendChild(wrapper);
                wrappers.push({ wrapper, clone, x, y });
            }
        }
    });

    // 4. נתיב וכדור אור
    if (wrappers.length > 0) {
        const networkSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        networkSvg.className = 'splash-network-svg';
        const pathEl = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        pathEl.className = 'splash-network-path';
        
        let d = `M ${centerX + wrappers[0].x} ${centerY + wrappers[0].y} `;
        wrappers.forEach(w => d += `L ${centerX + w.x} ${centerY + w.y} `);
        d += 'Z';
        pathEl.setAttribute('d', d);
        networkSvg.appendChild(pathEl);
        overlay.appendChild(networkSvg);

        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        circle.setAttribute('r', '7');
        circle.setAttribute('fill', '#ffd700');
        circle.innerHTML = `<animateMotion dur="2.5s" repeatCount="1" path="${d}" fill="freeze" />`;
        networkSvg.appendChild(circle);

        // הדלקה (Ignition)
        wrappers.forEach((w, i) => {
            setTimeout(() => {
                w.clone.classList.add('ignited');
            }, 500 * (i + 1));
        });
    }

    // 5. התכנסות וסגירה
    setTimeout(() => {
        wrappers.forEach(w => {
            w.wrapper.style.transform = `translate(0px, 0px) scale(0)`;
            w.wrapper.style.opacity = '0';
        });
        overlay.classList.add('fade-out');
    }, 3000);

    setTimeout(() => {
        overlay.remove();
        if (typeof onCompleteCallback === 'function') onCompleteCallback();
    }, 4000);
}