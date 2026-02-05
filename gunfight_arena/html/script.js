let currentZoneData = [];

// Récupérer le nom de la ressource une seule fois au chargement
const RESOURCE_NAME = (function() {
    if (typeof GetParentResourceName === 'function') {
        return GetParentResourceName();
    }
    return 'gunfight_arena';
})();

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.action) {
        case 'show':
            if (data.zones && data.zones.length > 0) {
                currentZoneData = data.zones;
            }
            showMainUI();
            break;
        case 'close':
            closeMainUI();
            break;
        case 'killFeed':
            addKillFeedMessage(data.message);
            break;
        case 'updateZonePlayers':
            updateZonePlayers(data.zones);
            break;
        case 'clearKillFeed':
            clearKillFeed();
            break;
        case 'showExitHud':
            showExitHud();
            break;
        case 'hideExitHud':
            hideExitHud();
            break;
    }
});

document.addEventListener('DOMContentLoaded', () => {
    const closeBtn = document.getElementById('close-main-btn');
    if (closeBtn) {
        closeBtn.addEventListener('click', closeMainUI);
    }
    
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            const mainUI = document.getElementById('main-ui');
            if (mainUI && mainUI.classList.contains('active')) {
                closeMainUI();
            }
        }
    });
});

function showMainUI() {
    const mainUI = document.getElementById('main-ui');
    if (!mainUI) return;
    mainUI.classList.add('active');
    renderZones();
}

function closeMainUI() {
    const mainUI = document.getElementById('main-ui');
    if (mainUI) {
        mainUI.classList.remove('active');
    }
    postNUI('closeUI', {});
}

function renderZones() {
    const zoneList = document.getElementById('zone-list');
    if (!zoneList) return;
    
    zoneList.innerHTML = "";
    
    currentZoneData.forEach((zone) => {
        const card = document.createElement('div');
        card.className = "zone-card";
        card.setAttribute("data-zone", zone.zone);
        
        const maxPlayers = zone.maxPlayers || 15;
        const currentPlayers = zone.players || 0;
        const isFull = currentPlayers >= maxPlayers;
        
        if (isFull) {
            card.setAttribute("data-full", "true");
        }
        
        card.innerHTML = `
            <img class="zone-image" src="${zone.image || 'images/default.webp'}" alt="${zone.label}" onerror="this.style.display='none'">
            <div class="zone-info">
                <div class="zone-text">${zone.label || 'Zone ' + zone.zone}</div>
                <div class="zone-players">
                    <span class="players-count">${currentPlayers}/${maxPlayers}</span>
                    <span class="zone-status ${isFull ? 'full' : ''}">${isFull ? 'COMPLET' : 'DISPONIBLE'}</span>
                </div>
            </div>
        `;
        
        if (!isFull) {
            card.addEventListener('click', () => selectZone(zone.zone));
        }
        
        zoneList.appendChild(card);
    });
}

function selectZone(zoneNumber) {
    console.log('[GF-UI] Zone sélectionnée:', zoneNumber);
    postNUI('zoneSelected', { zone: zoneNumber });
}

function updateZonePlayers(zones) {
    currentZoneData = zones;
    
    const mainUI = document.getElementById('main-ui');
    if (mainUI && mainUI.classList.contains('active')) {
        zones.forEach((zone) => {
            const card = document.querySelector(`.zone-card[data-zone="${zone.zone}"]`);
            if (card) {
                const maxPlayers = zone.maxPlayers || 15;
                const currentPlayers = zone.players || 0;
                const isFull = currentPlayers >= maxPlayers;
                
                const playersCount = card.querySelector('.players-count');
                const status = card.querySelector('.zone-status');
                
                if (playersCount) playersCount.textContent = `${currentPlayers}/${maxPlayers}`;
                if (status) {
                    status.textContent = isFull ? 'COMPLET' : 'DISPONIBLE';
                    status.classList.toggle('full', isFull);
                }
                
                if (isFull) {
                    card.setAttribute("data-full", "true");
                    card.onclick = null;
                } else {
                    card.removeAttribute("data-full");
                    card.onclick = () => selectZone(zone.zone);
                }
            }
        });
    }
}

function addKillFeedMessage(message) {
    const killfeedUI = document.getElementById('killfeed-ui');
    if (!killfeedUI) return;

    const div = document.createElement('div');
    div.className = 'kill-row';

    const killerId = message.killerId || '?';
    const victimId = message.victimId || '?';

    let multiplierHTML = '';
    if (message.multiplier && message.multiplier > 1) {
        multiplierHTML = `<div class="kill-multiplier">x${message.multiplier}</div>`;
    }

    div.innerHTML = `
        <div class="player-box killer-box">
            <span class="player-id">ID:${killerId}</span>
            <span class="killer-name">${message.killer}</span>
        </div>
        <div class="action-tag">A TUE</div>
        <div class="player-box">
            <span class="victim-name">${message.victim}</span>
            <span class="player-id">ID:${victimId}</span>
        </div>
        ${multiplierHTML}
    `;

    killfeedUI.prepend(div);

    // Maximum 6 kills visibles
    if (killfeedUI.children.length > 6) {
        const last = killfeedUI.lastElementChild;
        last.classList.add('kill-exit');
        setTimeout(() => last.remove(), 400);
    }

    setTimeout(() => {
        if (div.parentNode) {
            div.classList.add('kill-exit');
            setTimeout(() => div.remove(), 400);
        }
    }, 6000);
}

function clearKillFeed() {
    const killfeedUI = document.getElementById('killfeed-ui');
    if (killfeedUI) killfeedUI.innerHTML = '';
}

function showExitHud() {
    const el = document.getElementById('exit-hud');
    if (el) el.classList.add('active');
}

function hideExitHud() {
    const el = document.getElementById('exit-hud');
    if (el) el.classList.remove('active');
}

function postNUI(action, data) {
    data = data || {};
    fetch(`https://${RESOURCE_NAME}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(function() {});
}