// thank-button.js
function initThankButton() {
    const container = document.createElement('div');
    container.className = 'thank-fab-container';
    container.innerHTML = `
        <span>❤️</span>
        <span class="thank-label">תודה אישית ללי</span>
    `;

    document.body.appendChild(container);

    // התרחבות אחרי 4 שניות
    setTimeout(() => {
        if (container) container.classList.add('expanded');
    }, 4000);

    container.addEventListener('click', () => {
        // הטקסט עצמו מקודד (כפי שעשית), וזה מעולה
        const message = `לי,היי! קראתי את הברכה המקסימה! תודה רבה, חיממת לי את הלב.`;
        const phone = "972533386345";
        
        // יצירת הלינק המלא עם הקידוד
        const whatsappUrl = `whatsapp://send?phone=${phone}&text=${encodeURIComponent(message)}`;
        
        window.location.href = whatsappUrl;
    });
}