/**
 * =====================================================
 * REDZONE LEAGUE - Application JavaScript
 * =====================================================
 * Ce fichier gère toute la logique de l'interface NUI
 * Communication avec le client Lua via NUI callbacks
 */

// =====================================================
// CONFIGURATION
// =====================================================

const App = {
    // État de l'application
    isOpen: false,
    rulesAccepted: false,

    // Données reçues du serveur
    config: {},
    rules: {},
    spawnPoints: [],

    // Références DOM
    elements: {
        app: null,
        tabs: null,
        tabContents: null,
        rulesList: null,
        spawnGrid: null,
        acceptRulesCheckbox: null,
        acceptRulesBtn: null,
        closeBtn: null,
    },
};

// Shop state
const Shop = {
    isOpen: false,
    products: {},
    activeCategory: null,
    isVip: false,
    vipDiscount: 15,

    elements: {
        container: null,
        sidebar: null,
        grid: null,
        closeBtn: null,
    },
};

// =====================================================
// INITIALISATION
// =====================================================

/**
 * Initialise l'application au chargement du DOM
 */
document.addEventListener('DOMContentLoaded', () => {
    console.log('[REDZONE] Initialisation de l\'application...');

    // Récupération des éléments DOM
    App.elements = {
        app: document.getElementById('app'),
        tabs: document.querySelectorAll('.nav-tab'),
        tabContents: document.querySelectorAll('.tab-content'),
        rulesList: document.getElementById('rulesList'),
        spawnGrid: document.getElementById('spawnGrid'),
        acceptRulesCheckbox: document.getElementById('acceptRules'),
        acceptRulesBtn: document.getElementById('btnAcceptRules'),
        closeBtn: document.getElementById('btnClose'),
    };

    // Récupération des éléments DOM du Shop
    Shop.elements = {
        container: document.getElementById('shop-app'),
        sidebar: document.getElementById('shopSidebar'),
        grid: document.getElementById('shopGrid'),
        closeBtn: document.getElementById('shopBtnClose'),
    };

    // Initialisation des événements
    initializeEventListeners();
    initializeShopListeners();

    console.log('[REDZONE] Application initialisée');
});

/**
 * Configure tous les écouteurs d'événements
 */
function initializeEventListeners() {
    // Navigation par onglets
    App.elements.tabs.forEach(tab => {
        tab.addEventListener('click', () => switchTab(tab.dataset.tab));
    });

    // Checkbox d'acceptation des règles
    if (App.elements.acceptRulesCheckbox) {
        App.elements.acceptRulesCheckbox.addEventListener('change', (e) => {
            App.elements.acceptRulesBtn.disabled = !e.target.checked;
        });
    }

    // Bouton d'acceptation des règles
    if (App.elements.acceptRulesBtn) {
        App.elements.acceptRulesBtn.addEventListener('click', acceptRules);
    }

    // Bouton de fermeture
    if (App.elements.closeBtn) {
        App.elements.closeBtn.addEventListener('click', closeMenu);
    }

    // Écoute des messages NUI
    window.addEventListener('message', handleNUIMessage);

    // Écoute de la touche Échap
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (Shop.isOpen) {
                closeShop();
            } else if (App.isOpen) {
                closeMenu();
            }
        }
    });
}

// =====================================================
// COMMUNICATION NUI
// =====================================================

/**
 * Gère les messages reçus du client Lua
 * @param {MessageEvent} event - L'événement de message
 */
function handleNUIMessage(event) {
    const data = event.data;

    console.log('[REDZONE] Message NUI reçu:', data.action);

    switch (data.action) {
        case 'open':
            openMenu(data);
            break;

        case 'close':
            hideMenu();
            break;

        case 'updateStats':
            updateStats(data.stats);
            break;

        case 'openShop':
            openShop(data);
            break;

        case 'closeShop':
            hideShop();
            break;

        case 'updateVipStatus':
            updateVipStatus(data);
            break;

        case 'showDeathScreen':
            showDeathScreen(data);
            break;

        case 'hideDeathScreen':
            hideDeathScreen();
            break;

        case 'updateDeathScreen':
            updateDeathScreen(data);
            break;

        case 'showReviveProgress':
            showReviveProgress(data);
            break;

        case 'hideReviveProgress':
            hideReviveProgress();
            break;

        case 'showLootProgress':
            showLootProgress(data);
            break;

        case 'hideLootProgress':
            hideLootProgress();
            break;

        case 'showLaunderingProgress':
            showLaunderingProgress(data);
            break;

        case 'hideLaunderingProgress':
            hideLaunderingProgress();
            break;

        case 'showBandageProgress':
            showBandageProgress(data);
            break;

        case 'hideBandageProgress':
            hideBandageProgress();
            break;

        case 'openSquad':
            openSquadMenu(data);
            break;

        case 'closeSquad':
            closeSquadMenu();
            break;

        case 'showPressNotification':
            showPressNotification(data);
            break;

        case 'hidePressNotification':
            hidePressNotification();
            break;

        case 'addKillFeed':
            addKillFeed(data);
            break;

        case 'showPlayerInteract':
            showPlayerInteract(data);
            break;

        case 'hidePlayerInteract':
            hidePlayerInteract();
            break;

        default:
            console.log('[REDZONE] Action inconnue:', data.action);
    }
}

// Nom de la ressource (défini une seule fois pour éviter la récursion)
const RESOURCE_NAME = (() => {
    // Vérifie si on est dans FiveM (window.invokeNative existe)
    if (window.invokeNative) {
        return 'redzone';
    }
    return 'redzone';
})();

/**
 * Envoie un callback au client Lua
 * @param {string} name - Nom du callback
 * @param {object} data - Données à envoyer
 * @returns {Promise} - Promesse de la réponse
 */
async function sendCallback(name, data = {}) {
    try {
        const response = await fetch(`https://${RESOURCE_NAME}/${name}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });
        return await response.json();
    } catch (error) {
        console.error('[REDZONE] Erreur callback:', error);
        return null;
    }
}

// =====================================================
// GESTION DU MENU
// =====================================================

/**
 * Ouvre le menu avec les données fournies
 * @param {object} data - Données de configuration
 */
function openMenu(data) {
    console.log('[REDZONE] Ouverture du menu');

    // Sauvegarde des données
    if (data.config) App.config = data.config;
    if (data.rules) App.rules = data.rules;
    if (data.spawnPoints) App.spawnPoints = data.spawnPoints;

    // Rendu du contenu
    renderRules();
    renderSpawnPoints();

    // Affichage de l'interface
    showMenu();

    // Réinitialisation de l'état
    App.rulesAccepted = false;
    if (App.elements.acceptRulesCheckbox) {
        App.elements.acceptRulesCheckbox.checked = false;
    }
    if (App.elements.acceptRulesBtn) {
        App.elements.acceptRulesBtn.disabled = true;
    }

    // Retour à l'onglet des règles par défaut
    switchTab('rules');
}

/**
 * Affiche le menu
 */
function showMenu() {
    App.isOpen = true;
    App.elements.app.classList.remove('hidden');
}

/**
 * Cache le menu
 */
function hideMenu() {
    App.isOpen = false;
    App.elements.app.classList.add('hidden');
}

/**
 * Ferme le menu et envoie le callback
 */
function closeMenu() {
    console.log('[REDZONE] Fermeture du menu');
    hideMenu();
    sendCallback('closeMenu');
}

// =====================================================
// NAVIGATION PAR ONGLETS
// =====================================================

/**
 * Change d'onglet
 * @param {string} tabId - ID de l'onglet à afficher
 */
function switchTab(tabId) {
    console.log('[REDZONE] Changement d\'onglet:', tabId);

    // Mise à jour des boutons de navigation
    App.elements.tabs.forEach(tab => {
        if (tab.dataset.tab === tabId) {
            tab.classList.add('active');
        } else {
            tab.classList.remove('active');
        }
    });

    // Mise à jour du contenu
    App.elements.tabContents.forEach(content => {
        if (content.id === `tab-${tabId}`) {
            content.classList.add('active');
        } else {
            content.classList.remove('active');
        }
    });
}

// =====================================================
// RENDU DES RÈGLES
// =====================================================

/**
 * Génère le HTML des règles - Style simple et lisible
 */
function renderRules() {
    if (!App.elements.rulesList || !App.rules.Rules) return;

    const rulesHTML = App.rules.Rules.map((rule) => {
        // Détecter si c'est un titre de section (commence par §)
        if (rule.startsWith('§')) {
            return `<div class="rule-section"><span class="section-title">${rule.replace('§', '').trim()}</span></div>`;
        }

        // Détecter si c'est un avertissement (commence par ⚠)
        if (rule.startsWith('⚠')) {
            return `<div class="rule-warning"><span class="warning-text">${rule.replace('⚠', '⚠').trim()}</span></div>`;
        }

        // Détecter si c'est une règle autorisée (commence par ✓)
        if (rule.startsWith('✓')) {
            return `<div class="rule-item rule-allowed"><span class="rule-text">${rule.trim()}</span></div>`;
        }

        // Détecter si c'est une règle interdite (commence par ✗)
        if (rule.startsWith('✗')) {
            return `<div class="rule-item rule-forbidden"><span class="rule-text">${rule.trim()}</span></div>`;
        }

        // Règle normale - simple bullet point
        const ruleText = rule.replace(/^\d+\.\s*/, '').trim();
        return `<div class="rule-item"><span class="rule-text">• ${ruleText}</span></div>`;
    }).join('');

    App.elements.rulesList.innerHTML = rulesHTML;
}

/**
 * Accepte les règles
 */
function acceptRules() {
    if (!App.elements.acceptRulesCheckbox?.checked) return;

    App.rulesAccepted = true;
    console.log('[REDZONE] Règles acceptées');

    // Envoi du callback
    sendCallback('confirmRules');

    // Passage à l'onglet des zones
    switchTab('spawn');
}

// =====================================================
// RENDU DES POINTS DE SPAWN
// =====================================================

/**
 * Génère le HTML des points de spawn
 */
function renderSpawnPoints() {
    if (!App.elements.spawnGrid || !App.spawnPoints) return;

    const spawnsHTML = App.spawnPoints.map(spawn => {
        return `
            <div class="spawn-card" data-spawn-id="${spawn.id}" onclick="selectSpawn(${spawn.id})">
                <div class="spawn-header">
                    <div class="spawn-icon">
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                            <circle cx="12" cy="10" r="3"></circle>
                        </svg>
                    </div>
                    <div class="spawn-info">
                        <div class="spawn-name">${spawn.name}</div>
                        <div class="spawn-id">Zone #${spawn.id}</div>
                    </div>
                </div>
                <p class="spawn-description">
                    Téléportez-vous vers cette zone pour rejoindre le combat.
                    ${spawn.blip ? `<br><small>Visible sur la carte</small>` : ''}
                </p>
                <div class="spawn-action">
                    <button class="spawn-btn">
                        <span>Rejoindre</span>
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <line x1="5" y1="12" x2="19" y2="12"></line>
                            <polyline points="12 5 19 12 12 19"></polyline>
                        </svg>
                    </button>
                </div>
            </div>
        `;
    }).join('');

    App.elements.spawnGrid.innerHTML = spawnsHTML;
}

/**
 * Sélectionne un point de spawn
 * @param {number} spawnId - ID du point de spawn
 */
function selectSpawn(spawnId) {
    console.log('[REDZONE] Spawn sélectionné:', spawnId);

    // Vérification que les règles sont acceptées
    if (!App.rulesAccepted) {
        // Afficher un message ou changer d'onglet
        switchTab('rules');
        highlightRulesCheckbox();
        return;
    }

    // Envoi du callback avec l'ID du spawn
    sendCallback('selectSpawn', { spawnId: spawnId });
}

/**
 * Met en évidence la checkbox des règles
 */
function highlightRulesCheckbox() {
    const checkbox = App.elements.acceptRulesCheckbox?.parentElement;
    if (checkbox) {
        checkbox.style.animation = 'none';
        checkbox.offsetHeight; // Force reflow
        checkbox.style.animation = 'shake 0.5s ease';
    }
}

// =====================================================
// MISE À JOUR DES STATISTIQUES
// =====================================================

/**
 * Met à jour l'affichage des statistiques
 * @param {object} stats - Statistiques du joueur
 */
function updateStats(stats) {
    if (!stats) return;

    const statKills = document.getElementById('statKills');
    const statDeaths = document.getElementById('statDeaths');
    const statKD = document.getElementById('statKD');
    const statTime = document.getElementById('statTime');

    if (statKills && stats.kills !== undefined) {
        statKills.textContent = stats.kills;
    }

    if (statDeaths && stats.deaths !== undefined) {
        statDeaths.textContent = stats.deaths;
    }

    if (statKD) {
        const kd = stats.deaths > 0 ? (stats.kills / stats.deaths).toFixed(2) : stats.kills.toFixed(2);
        statKD.textContent = kd;
    }

    if (statTime && stats.playTime !== undefined) {
        statTime.textContent = formatPlayTime(stats.playTime);
    }
}

/**
 * Formate le temps de jeu
 * @param {number} seconds - Temps en secondes
 * @returns {string} - Temps formaté
 */
function formatPlayTime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
        return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
}

// =====================================================
// ANIMATIONS
// =====================================================

// Animation de shake pour les erreurs
const shakeKeyframes = `
    @keyframes shake {
        0%, 100% { transform: translateX(0); }
        10%, 30%, 50%, 70%, 90% { transform: translateX(-5px); }
        20%, 40%, 60%, 80% { transform: translateX(5px); }
    }
`;

// Injection du CSS d'animation
const styleSheet = document.createElement('style');
styleSheet.textContent = shakeKeyframes;
document.head.appendChild(styleSheet);

// =====================================================
// SHOP ARMES - LOGIQUE
// =====================================================

/**
 * Initialise les écouteurs d'événements du shop
 */
function initializeShopListeners() {
    if (Shop.elements.closeBtn) {
        Shop.elements.closeBtn.addEventListener('click', closeShop);
    }
}

/**
 * Ouvre le shop avec les données de produits
 * @param {object} data - Données contenant les produits par catégorie
 */
function openShop(data) {
    console.log('[REDZONE/SHOP] Ouverture du shop');

    if (data.products) {
        Shop.products = data.products;
    }
    if (data.isVip !== undefined) {
        Shop.isVip = data.isVip;
    }
    if (data.vipDiscount !== undefined) {
        Shop.vipDiscount = data.vipDiscount;
    }

    // Déterminer la première catégorie (Items en premier)
    const categoryOrder = ['Items', 'Munitions', 'Pistols', 'SMGs', 'Rifles', 'Shotguns', 'MGs'];
    const categories = Object.keys(Shop.products).sort((a, b) => {
        return categoryOrder.indexOf(a) - categoryOrder.indexOf(b);
    });
    if (categories.length > 0) {
        Shop.activeCategory = categories[0];
    }

    // Rendu
    renderShopSidebar();
    renderShopGrid();

    // Afficher
    showShop();
}

/**
 * Met à jour le statut VIP
 * @param {object} data - Données VIP
 */
function updateVipStatus(data) {
    if (data.isVip !== undefined) {
        Shop.isVip = data.isVip;
    }
    if (data.vipDiscount !== undefined) {
        Shop.vipDiscount = data.vipDiscount;
    }
    // Re-render si le shop est ouvert
    if (Shop.isOpen) {
        renderShopSidebar();
        renderShopGrid();
    }
}

/**
 * Affiche le shop
 */
function showShop() {
    Shop.isOpen = true;
    if (Shop.elements.container) {
        Shop.elements.container.classList.remove('hidden');
    }
}

/**
 * Cache le shop
 */
function hideShop() {
    Shop.isOpen = false;
    if (Shop.elements.container) {
        Shop.elements.container.classList.add('hidden');
    }
}

/**
 * Ferme le shop et envoie le callback
 */
function closeShop() {
    console.log('[REDZONE/SHOP] Fermeture du shop');
    hideShop();
    sendCallback('closeShop');
}

/**
 * Formate un prix avec séparateur de milliers
 * @param {number} price - Le prix à formater
 * @returns {string} Prix formaté
 */
function formatPrice(price) {
    return '$' + price.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/**
 * Calcule le prix avec réduction VIP
 * @param {number} basePrice - Prix de base
 * @returns {number} Prix final
 */
function getDiscountedPrice(basePrice) {
    if (Shop.isVip) {
        return Math.floor(basePrice * (1 - Shop.vipDiscount / 100));
    }
    return basePrice;
}

/**
 * Rendu de la sidebar catégories
 */
function renderShopSidebar() {
    if (!Shop.elements.sidebar) return;

    const categoryLabels = {
        'Items': 'Soins',
        'Munitions': 'Munitions',
        'Pistols': 'Pistolets',
        'SMGs': 'SMGs',
        'Rifles': 'Fusils',
        'Shotguns': 'Shotguns',
        'MGs': 'Mitrailleuses',
    };

    const categoryIcons = {
        'Items': '&#128138;',
        'Munitions': '&#128163;',
        'Pistols': '&#128299;',
        'SMGs': '&#9889;',
        'Rifles': '&#127919;',
        'Shotguns': '&#128165;',
        'MGs': '&#128293;',
    };

    // Ordre d'affichage
    const categoryOrder = ['Items', 'Munitions', 'Pistols', 'SMGs', 'Rifles', 'Shotguns', 'MGs'];
    const categories = Object.keys(Shop.products).sort((a, b) => {
        return categoryOrder.indexOf(a) - categoryOrder.indexOf(b);
    });

    // Badge VIP
    let vipBadge = '';
    if (Shop.isVip) {
        vipBadge = `<div class="shop-vip-badge">VIP -${Shop.vipDiscount}%</div>`;
    }

    const categoriesHtml = categories.map(cat => {
        const isActive = cat === Shop.activeCategory ? 'active' : '';
        const label = categoryLabels[cat] || cat;
        const icon = categoryIcons[cat] || '&#8226;';
        return `
            <button class="shop-category ${isActive}" data-category="${cat}" onclick="selectShopCategory('${cat}')">
                <span class="shop-category-icon">${icon}</span>
                <span>${label}</span>
            </button>
        `;
    }).join('');

    Shop.elements.sidebar.innerHTML = vipBadge + categoriesHtml;
}

/**
 * Sélectionne une catégorie
 * @param {string} category - Nom de la catégorie
 */
function selectShopCategory(category) {
    Shop.activeCategory = category;
    renderShopSidebar();
    renderShopGrid();
}

// Stockage des quantités sélectionnées pour les munitions
const ammoQuantities = {};

/**
 * Rendu de la grille de produits
 */
function renderShopGrid() {
    if (!Shop.elements.grid || !Shop.activeCategory) return;

    const products = Shop.products[Shop.activeCategory] || [];

    const html = products.map(product => {
        const isAmmo = product.type === 'ammo';
        const defaultQty = product.ammoAmount || 50;

        // Initialiser la quantité si pas encore fait
        if (isAmmo && !ammoQuantities[product.model]) {
            ammoQuantities[product.model] = defaultQty;
        }

        const quantity = isAmmo ? ammoQuantities[product.model] : 1;
        const basePrice = product.price || 0;
        const unitPrice = getDiscountedPrice(basePrice);
        const totalPrice = isAmmo ? unitPrice * quantity : unitPrice;
        const baseTotal = isAmmo ? basePrice * quantity : basePrice;
        const hasDiscount = Shop.isVip && unitPrice < basePrice;

        let priceHtml = '';
        if (isAmmo) {
            // Affichage prix pour munitions (prix unitaire × quantité)
            if (hasDiscount) {
                priceHtml = `
                    <div class="shop-weapon-price">
                        <span class="shop-price-unit">${formatPrice(unitPrice)}/unité</span>
                        <span class="shop-price-original">${formatPrice(baseTotal)}</span>
                        <span class="shop-price-final">${formatPrice(totalPrice)}</span>
                    </div>
                `;
            } else {
                priceHtml = `
                    <div class="shop-weapon-price">
                        <span class="shop-price-unit">${formatPrice(basePrice)}/unité</span>
                        <span class="shop-price-final">${formatPrice(totalPrice)}</span>
                    </div>
                `;
            }
        } else {
            // Affichage prix normal
            if (hasDiscount) {
                priceHtml = `
                    <div class="shop-weapon-price">
                        <span class="shop-price-original">${formatPrice(basePrice)}</span>
                        <span class="shop-price-final">${formatPrice(unitPrice)}</span>
                    </div>
                `;
            } else {
                priceHtml = `
                    <div class="shop-weapon-price">
                        <span class="shop-price-final">${formatPrice(basePrice)}</span>
                    </div>
                `;
            }
        }

        // Image du produit
        const imageUrl = product.image ? `assets/${product.image}` : null;
        let imageHtml = '';
        if (imageUrl) {
            imageHtml = `<img src="${imageUrl}" alt="${product.name}" class="shop-product-image" onerror="this.style.display='none'">`;
        } else {
            imageHtml = `
                <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <path d="M2 12h6l2-3h4l2 3h6"></path>
                    <path d="M12 3v6"></path>
                    <circle cx="12" cy="12" r="2"></circle>
                </svg>
            `;
        }

        // Sélecteur de quantité pour les munitions
        let quantityHtml = '';
        if (isAmmo) {
            quantityHtml = `
                <div class="shop-quantity-selector">
                    <button class="shop-qty-btn" onclick="changeAmmoQty('${product.model}', -10)">-10</button>
                    <button class="shop-qty-btn" onclick="changeAmmoQty('${product.model}', -1)">-</button>
                    <input type="number" class="shop-qty-input" id="qty-${product.model}" value="${quantity}" min="1" max="500" onchange="setAmmoQty('${product.model}', this.value)">
                    <button class="shop-qty-btn" onclick="changeAmmoQty('${product.model}', 1)">+</button>
                    <button class="shop-qty-btn" onclick="changeAmmoQty('${product.model}', 10)">+10</button>
                </div>
            `;
        }

        return `
            <div class="shop-weapon-card ${isAmmo ? 'shop-ammo-card' : ''}">
                <div class="shop-product-icon">
                    ${imageHtml}
                </div>
                <span class="shop-weapon-name">${product.name}</span>
                ${quantityHtml}
                ${priceHtml}
                <button class="shop-btn-equip" onclick="buyProduct('${product.model}', ${isAmmo})">
                    Acheter
                </button>
            </div>
        `;
    }).join('');

    Shop.elements.grid.innerHTML = html;
}

/**
 * Change la quantité de munitions
 * @param {string} model - Modèle de la munition
 * @param {number} delta - Changement de quantité (+/-)
 */
function changeAmmoQty(model, delta) {
    const current = ammoQuantities[model] || 50;
    let newQty = current + delta;
    newQty = Math.max(1, Math.min(500, newQty));
    ammoQuantities[model] = newQty;

    // Mettre à jour l'input
    const input = document.getElementById(`qty-${model}`);
    if (input) input.value = newQty;

    // Re-render pour mettre à jour le prix
    renderShopGrid();
}

/**
 * Définit la quantité de munitions
 * @param {string} model - Modèle de la munition
 * @param {string|number} value - Nouvelle quantité
 */
function setAmmoQty(model, value) {
    let qty = parseInt(value) || 50;
    qty = Math.max(1, Math.min(500, qty));
    ammoQuantities[model] = qty;

    // Re-render pour mettre à jour le prix
    renderShopGrid();
}

/**
 * Achète un produit (envoie le callback)
 * @param {string} model - Modèle du produit
 * @param {boolean} isAmmo - Si c'est des munitions
 */
function buyProduct(model, isAmmo) {
    const quantity = isAmmo ? ammoQuantities[model] : null;
    console.log('[REDZONE/SHOP] Achat:', model, isAmmo ? `x${quantity}` : '');
    sendCallback('buyWeapon', { model: model, quantity: quantity });
}

// =====================================================
// DEATH SCREEN - LOGIQUE
// =====================================================

// État de l'écran de mort
const DeathScreen = {
    isVisible: false,
    timer: 0,
    timerInterval: null,
    maxTimer: 30,
};

/**
 * Met à jour l'affichage du timer avec les boîtes séparées
 * @param {number} totalSeconds - Temps en secondes
 */
function updateDeathTimerDisplay(totalSeconds) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;

    const minStr = minutes.toString().padStart(2, '0');
    const secStr = seconds.toString().padStart(2, '0');

    const minTens = document.getElementById('minTens');
    const minUnits = document.getElementById('minUnits');
    const secTens = document.getElementById('secTens');
    const secUnits = document.getElementById('secUnits');

    if (minTens) minTens.textContent = minStr[0];
    if (minUnits) minUnits.textContent = minStr[1];
    if (secTens) secTens.textContent = secStr[0];
    if (secUnits) secUnits.textContent = secStr[1];
}

/**
 * Affiche l'écran de mort
 * @param {object} data - Données (timer, message)
 */
function showDeathScreen(data) {
    console.log('[REDZONE/DEATH] Affichage écran de mort');

    DeathScreen.isVisible = true;
    DeathScreen.timer = data.timer || 30;
    DeathScreen.maxTimer = data.timer || 30;

    const container = document.getElementById('death-screen');
    const messageEl = document.getElementById('deathMessage');
    const hintEl = document.getElementById('deathHint');
    const titleEl = document.getElementById('deathTitle');

    if (container) container.classList.remove('hidden');
    if (messageEl) messageEl.textContent = data.message || 'Vous êtes gravement blessé';
    if (titleEl) titleEl.textContent = 'VOUS ÊTES EN TRAIN DE MOURIR';
    if (hintEl) hintEl.innerHTML = 'UN ALLIÉ PEUT VOUS RÉANIMER AVEC UN <span class="death-key">MEDIKIT</span>';

    // Mettre à jour le timer
    updateDeathTimerDisplay(DeathScreen.timer);

    // Démarrer le timer
    startDeathTimer();
}

/**
 * Cache l'écran de mort
 */
function hideDeathScreen() {
    console.log('[REDZONE/DEATH] Masquage écran de mort');

    DeathScreen.isVisible = false;
    DeathScreen.timer = 0;
    DeathScreen.maxTimer = 30;

    const container = document.getElementById('death-screen');
    if (container) container.classList.add('hidden');

    // Arrêter le timer
    if (DeathScreen.timerInterval) {
        clearInterval(DeathScreen.timerInterval);
        DeathScreen.timerInterval = null;
    }

    // Reset les éléments visuels
    const messageEl = document.getElementById('deathMessage');
    const hintEl = document.getElementById('deathHint');
    const titleEl = document.getElementById('deathTitle');

    updateDeathTimerDisplay(30);
    if (messageEl) messageEl.textContent = 'Vous êtes gravement blessé';
    if (titleEl) titleEl.textContent = 'VOUS ÊTES EN TRAIN DE MOURIR';
    if (hintEl) hintEl.innerHTML = 'UN ALLIÉ PEUT VOUS RÉANIMER AVEC UN <span class="death-key">MEDIKIT</span>';
}

/**
 * Met à jour l'écran de mort
 * @param {object} data - Données à mettre à jour
 */
function updateDeathScreen(data) {
    const messageEl = document.getElementById('deathMessage');
    const hintEl = document.getElementById('deathHint');
    const titleEl = document.getElementById('deathTitle');

    if (messageEl && data.message) {
        messageEl.textContent = data.message;
    }

    if (data.beingRevived) {
        // En cours de réanimation
        if (titleEl) {
            titleEl.textContent = 'RÉANIMATION EN COURS';
            titleEl.style.color = '#22c55e';
        }
        if (hintEl) {
            hintEl.innerHTML = 'UN ALLIÉ VOUS RÉANIME...';
        }
    } else if (data.canRespawn) {
        // Timer expiré, peut respawn
        if (titleEl) {
            titleEl.textContent = 'VOUS POUVEZ RESPAWN';
            titleEl.style.color = '#ff0000';
        }
        if (hintEl) {
            hintEl.innerHTML = 'APPUYEZ SUR <span class="death-key">BACKSPACE</span> POUR RESPAWN EN ZONE SAFE';
        }
    } else {
        if (titleEl) {
            titleEl.textContent = 'VOUS ÊTES EN TRAIN DE MOURIR';
            titleEl.style.color = '#ff0000';
        }
        if (hintEl) {
            hintEl.innerHTML = 'UN ALLIÉ PEUT VOUS RÉANIMER AVEC UN <span class="death-key">MEDIKIT</span>';
        }
    }
}

/**
 * Démarre le timer de mort
 */
function startDeathTimer() {
    if (DeathScreen.timerInterval) {
        clearInterval(DeathScreen.timerInterval);
    }

    DeathScreen.timerInterval = setInterval(() => {
        DeathScreen.timer--;

        // Mettre à jour l'affichage du timer
        updateDeathTimerDisplay(Math.max(0, DeathScreen.timer));

        // Timer expiré - Le joueur peut maintenant choisir
        if (DeathScreen.timer <= 0) {
            clearInterval(DeathScreen.timerInterval);
            DeathScreen.timerInterval = null;

            // Afficher 00:00
            updateDeathTimerDisplay(0);

            // Note: Le message sera mis à jour par le callback 'updateDeathScreen' du client Lua
            // quand canRespawn devient true
        }
    }, 1000);
}

// Variables pour le revive
let reviveInterval = null;
let reviveAnimationFrame = null;

/**
 * Affiche le cercle de progression de réanimation
 * @param {object} data - Données (duration en secondes)
 */
function showReviveProgress(data) {
    console.log('[REDZONE/REVIVE] Affichage progression réanimation');

    const container = document.getElementById('reviveProgressContainer');
    const circleProgress = document.getElementById('reviveCircleProgress');
    const timerEl = document.getElementById('reviveTimer');

    if (!container || !circleProgress || !timerEl) return;

    // Afficher le container
    container.classList.remove('hidden');

    // Configuration
    const duration = (data.duration || 10) * 1000; // 10 secondes par defaut
    const totalSeconds = Math.ceil(duration / 1000);
    const circumference = 2 * Math.PI * 45; // rayon = 45

    // Reset
    circleProgress.style.strokeDasharray = circumference;
    circleProgress.style.strokeDashoffset = circumference;
    timerEl.textContent = totalSeconds;

    // Nettoyer les anciens intervals
    if (reviveInterval) clearInterval(reviveInterval);
    if (reviveAnimationFrame) cancelAnimationFrame(reviveAnimationFrame);

    const startTime = Date.now();
    let remainingSeconds = totalSeconds;

    // Timer pour les secondes
    reviveInterval = setInterval(() => {
        remainingSeconds--;
        if (timerEl) timerEl.textContent = Math.max(0, remainingSeconds);

        if (remainingSeconds <= 0) {
            clearInterval(reviveInterval);
            reviveInterval = null;
        }
    }, 1000);

    // Animation fluide du cercle
    const updateProgress = () => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(1, elapsed / duration);

        // Calculer le stroke-dashoffset (de circumference a 0)
        const offset = circumference * (1 - progress);
        if (circleProgress) circleProgress.style.strokeDashoffset = offset;

        if (elapsed < duration && container && !container.classList.contains('hidden')) {
            reviveAnimationFrame = requestAnimationFrame(updateProgress);
        }
    };

    reviveAnimationFrame = requestAnimationFrame(updateProgress);
}

/**
 * Cache le cercle de progression de réanimation
 */
function hideReviveProgress() {
    console.log('[REDZONE/REVIVE] Masquage progression réanimation');

    const container = document.getElementById('reviveProgressContainer');
    if (container) container.classList.add('hidden');

    // Nettoyer
    if (reviveInterval) {
        clearInterval(reviveInterval);
        reviveInterval = null;
    }
    if (reviveAnimationFrame) {
        cancelAnimationFrame(reviveAnimationFrame);
        reviveAnimationFrame = null;
    }
}

// =====================================================
// LOOT PROGRESS - LOGIQUE
// =====================================================

// Variables pour le loot
let lootInterval = null;
let lootAnimationFrame = null;

/**
 * Affiche le cercle de progression de loot
 * @param {object} data - Données (duration en secondes)
 */
function showLootProgress(data) {
    console.log('[REDZONE/LOOT] Affichage progression loot');

    const container = document.getElementById('lootProgressContainer');
    const circleProgress = document.getElementById('lootCircleProgress');
    const timerEl = document.getElementById('lootTimer');

    if (!container || !circleProgress || !timerEl) return;

    // Afficher le container
    container.classList.remove('hidden');

    // Configuration
    const duration = (data.duration || 7) * 1000;
    const totalSeconds = Math.ceil(duration / 1000);
    const circumference = 2 * Math.PI * 45; // rayon = 45

    // Reset
    circleProgress.style.strokeDasharray = circumference;
    circleProgress.style.strokeDashoffset = circumference;
    timerEl.textContent = totalSeconds;

    // Nettoyer les anciens intervals
    if (lootInterval) clearInterval(lootInterval);
    if (lootAnimationFrame) cancelAnimationFrame(lootAnimationFrame);

    const startTime = Date.now();
    let remainingSeconds = totalSeconds;

    // Timer pour les secondes
    lootInterval = setInterval(() => {
        remainingSeconds--;
        if (timerEl) timerEl.textContent = Math.max(0, remainingSeconds);

        if (remainingSeconds <= 0) {
            clearInterval(lootInterval);
            lootInterval = null;
        }
    }, 1000);

    // Animation fluide du cercle
    const updateProgress = () => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(1, elapsed / duration);

        // Calculer le stroke-dashoffset (de circumference a 0)
        const offset = circumference * (1 - progress);
        if (circleProgress) circleProgress.style.strokeDashoffset = offset;

        if (elapsed < duration && container && !container.classList.contains('hidden')) {
            lootAnimationFrame = requestAnimationFrame(updateProgress);
        }
    };

    lootAnimationFrame = requestAnimationFrame(updateProgress);
}

/**
 * Cache le cercle de progression de loot
 */
function hideLootProgress() {
    console.log('[REDZONE/LOOT] Masquage progression loot');

    const container = document.getElementById('lootProgressContainer');
    if (container) container.classList.add('hidden');

    // Nettoyer
    if (lootInterval) {
        clearInterval(lootInterval);
        lootInterval = null;
    }
    if (lootAnimationFrame) {
        cancelAnimationFrame(lootAnimationFrame);
        lootAnimationFrame = null;
    }
}

// =====================================================
// LAUNDERING PROGRESS - LOGIQUE
// =====================================================

/**
 * Affiche la barre de progression de blanchiment
 * @param {object} data - Données (duration en secondes)
 */
function showLaunderingProgress(data) {
    const container = document.getElementById('launderingProgressContainer');
    const fillEl = document.getElementById('launderingProgressFill');

    if (container) container.classList.remove('hidden');
    if (fillEl) fillEl.style.width = '0%';

    // Animer la barre
    const duration = (data.duration || 3) * 1000;
    const startTime = Date.now();

    const updateProgress = () => {
        const elapsed = Date.now() - startTime;
        const percent = Math.min(100, (elapsed / duration) * 100);

        if (fillEl) fillEl.style.width = `${percent}%`;

        if (elapsed < duration && container && !container.classList.contains('hidden')) {
            requestAnimationFrame(updateProgress);
        }
    };

    requestAnimationFrame(updateProgress);
}

/**
 * Cache la barre de progression de blanchiment
 */
function hideLaunderingProgress() {
    const container = document.getElementById('launderingProgressContainer');
    if (container) container.classList.add('hidden');
}

// =====================================================
// BANDAGE PROGRESS - LOGIQUE
// =====================================================

// Variables pour le bandage
let bandageInterval = null;
let bandageAnimationFrame = null;

/**
 * Affiche le cercle de progression du bandage
 * @param {object} data - Données (duration en secondes)
 */
function showBandageProgress(data) {
    console.log('[REDZONE/BANDAGE] Affichage progression bandage');

    const container = document.getElementById('bandageProgressContainer');
    const circleProgress = document.getElementById('bandageCircleProgress');
    const timerEl = document.getElementById('bandageTimer');

    if (!container || !circleProgress || !timerEl) return;

    // Afficher le container
    container.classList.remove('hidden');

    // Configuration
    const duration = (data.duration || 8) * 1000; // 8 secondes par defaut
    const totalSeconds = Math.ceil(duration / 1000);
    const circumference = 2 * Math.PI * 45; // rayon = 45

    // Reset
    circleProgress.style.strokeDasharray = circumference;
    circleProgress.style.strokeDashoffset = circumference;
    timerEl.textContent = totalSeconds;

    // Nettoyer les anciens intervals
    if (bandageInterval) clearInterval(bandageInterval);
    if (bandageAnimationFrame) cancelAnimationFrame(bandageAnimationFrame);

    const startTime = Date.now();
    let remainingSeconds = totalSeconds;

    // Timer pour les secondes
    bandageInterval = setInterval(() => {
        remainingSeconds--;
        if (timerEl) timerEl.textContent = Math.max(0, remainingSeconds);

        if (remainingSeconds <= 0) {
            clearInterval(bandageInterval);
            bandageInterval = null;
        }
    }, 1000);

    // Animation fluide du cercle
    const updateProgress = () => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(1, elapsed / duration);

        // Calculer le stroke-dashoffset (de circumference a 0)
        const offset = circumference * (1 - progress);
        if (circleProgress) circleProgress.style.strokeDashoffset = offset;

        if (elapsed < duration && container && !container.classList.contains('hidden')) {
            bandageAnimationFrame = requestAnimationFrame(updateProgress);
        }
    };

    bandageAnimationFrame = requestAnimationFrame(updateProgress);
}

/**
 * Cache le cercle de progression du bandage
 */
function hideBandageProgress() {
    console.log('[REDZONE/BANDAGE] Masquage progression bandage');

    const container = document.getElementById('bandageProgressContainer');
    if (container) container.classList.add('hidden');

    // Nettoyer
    if (bandageInterval) {
        clearInterval(bandageInterval);
        bandageInterval = null;
    }
    if (bandageAnimationFrame) {
        cancelAnimationFrame(bandageAnimationFrame);
        bandageAnimationFrame = null;
    }
}

/**
 * Clic sur le bouton de respawn
 */
document.addEventListener('DOMContentLoaded', () => {
    const respawnBtn = document.getElementById('deathRespawnBtn');
    if (respawnBtn) {
        respawnBtn.addEventListener('click', () => {
            sendCallback('requestRespawn', {});
        });
    }
});

// =====================================================
// SQUAD MENU - LOGIQUE
// =====================================================

const Squad = {
    isOpen: false,
    data: null,
};

/**
 * Ouvre le menu squad
 * @param {object} data - Données du squad
 */
function openSquadMenu(data) {
    console.log('[REDZONE/SQUAD] Ouverture du menu squad', data);

    Squad.isOpen = true;
    Squad.data = data;

    const container = document.getElementById('squad-app');
    const content = document.getElementById('squadContent');

    if (container) container.classList.remove('hidden');

    if (content) {
        content.innerHTML = renderSquadContent(data);
    }

    // Ajouter les event listeners
    initSquadListeners();
}

/**
 * Ferme le menu squad
 */
function closeSquadMenu() {
    Squad.isOpen = false;
    Squad.data = null;

    const container = document.getElementById('squad-app');
    if (container) container.classList.add('hidden');
}

/**
 * Génère le contenu HTML du menu squad
 * @param {object} data - Données du squad
 * @returns {string} HTML
 */
function renderSquadContent(data) {
    let html = '';

    // Afficher l'invitation en attente si présente
    if (data.hasPendingInvite && data.invite) {
        html += `
            <div class="squad-invite">
                <div class="squad-invite-title">Invitation reçue</div>
                <div class="squad-invite-text">
                    <strong>${data.invite.hostName}</strong> vous invite à rejoindre son squad.
                </div>
                <div class="squad-invite-buttons">
                    <button class="squad-btn-accept" id="squadAcceptInvite">Accepter</button>
                    <button class="squad-btn-decline" id="squadDeclineInvite">Refuser</button>
                </div>
            </div>
        `;
    }

    // Si pas de squad
    if (!data.hasSquad) {
        html += `
            <div class="squad-no-squad">
                <div class="squad-no-squad-text">
                    Aucun groupe détecté.<br>
                    Lancez une nouvelle session.
                </div>
                <button class="squad-btn-create" id="squadCreate">Créer le Groupe</button>
            </div>
        `;
    } else {
        // Afficher le squad
        const squad = data.squad;
        const memberCount = squad.members.length;
        const maxMembers = data.maxMembers || 4;

        html += `
            <div class="squad-info">
                <div class="squad-members-list">
        `;

        // Afficher les membres
        for (const member of squad.members) {
            const isHost = member.isHost;
            const initial = member.name.charAt(0).toUpperCase();
            const canKick = squad.isHost && !isHost;
            const roleText = isHost ? 'Propriétaire' : 'Membre';

            html += `
                <div class="squad-member ${isHost ? 'host' : ''}">
                    <div class="squad-member-info">
                        <div class="squad-member-avatar">${initial}</div>
                        <div class="squad-member-details">
                            <b class="squad-member-name">${member.name}</b>
                            <span class="squad-member-role ${isHost ? 'host-role' : ''}">${roleText} • ID ${member.id}</span>
                        </div>
                    </div>
                    ${canKick ? `<button class="squad-btn-kick" data-player-id="${member.id}">Kick</button>` : ''}
                </div>
            `;
        }

        html += `
                </div>
            </div>
        `;

        // Section invitation (hôte seulement)
        if (squad.isHost && memberCount < maxMembers) {
            html += `
                <div class="squad-invite-section">
                    <div class="squad-invite-input-group">
                        <input type="number" class="squad-invite-input" id="squadInviteInput" placeholder="Entrer l'identifiant du joueur" min="1">
                        <button class="squad-btn-invite" id="squadInviteBtn">Inviter</button>
                    </div>
                </div>
            `;
        }

        // Actions
        html += `<div class="squad-actions">`;

        if (squad.isHost) {
            html += `<button class="squad-btn-disband" id="squadDisband">Dissoudre la session actuelle</button>`;
        } else {
            html += `<button class="squad-btn-leave" id="squadLeave">Quitter la session actuelle</button>`;
        }

        html += `</div>`;
    }

    return html;
}

/**
 * Initialise les listeners du menu squad
 */
function initSquadListeners() {
    // Bouton fermer
    const closeBtn = document.getElementById('squadBtnClose');
    if (closeBtn) {
        closeBtn.onclick = () => {
            sendCallback('closeSquadMenu');
            closeSquadMenu();
        };
    }

    // Bouton créer
    const createBtn = document.getElementById('squadCreate');
    if (createBtn) {
        createBtn.onclick = () => sendCallback('createSquad');
    }

    // Bouton quitter
    const leaveBtn = document.getElementById('squadLeave');
    if (leaveBtn) {
        leaveBtn.onclick = () => sendCallback('leaveSquad');
    }

    // Bouton dissoudre
    const disbandBtn = document.getElementById('squadDisband');
    if (disbandBtn) {
        disbandBtn.onclick = () => sendCallback('disbandSquad');
    }

    // Bouton inviter
    const inviteBtn = document.getElementById('squadInviteBtn');
    const inviteInput = document.getElementById('squadInviteInput');
    if (inviteBtn && inviteInput) {
        inviteBtn.onclick = () => {
            const playerId = inviteInput.value.trim();
            if (playerId) {
                sendCallback('invitePlayer', { playerId: playerId });
                inviteInput.value = '';
            }
        };

        // Enter pour inviter
        inviteInput.onkeypress = (e) => {
            if (e.key === 'Enter') {
                inviteBtn.click();
            }
        };
    }

    // Boutons kick
    const kickBtns = document.querySelectorAll('.squad-btn-kick');
    kickBtns.forEach(btn => {
        btn.onclick = () => {
            const playerId = btn.dataset.playerId;
            if (playerId) {
                sendCallback('kickPlayer', { playerId: playerId });
            }
        };
    });

    // Accepter invitation
    const acceptBtn = document.getElementById('squadAcceptInvite');
    if (acceptBtn) {
        acceptBtn.onclick = () => sendCallback('acceptInvite');
    }

    // Refuser invitation
    const declineBtn = document.getElementById('squadDeclineInvite');
    if (declineBtn) {
        declineBtn.onclick = () => sendCallback('declineInvite');
    }
}

// Fermer le menu squad avec ESC
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && Squad.isOpen) {
        sendCallback('closeSquadMenu');
        closeSquadMenu();
    }
});

// =====================================================
// PRESS NOTIFICATION - LOGIQUE
// =====================================================

let pressNotificationTimeout = null;

/**
 * Affiche la notification de press
 * @param {object} data - Données de la notification
 */
function showPressNotification(data) {
    console.log('[REDZONE/PRESS] Affichage notification press:', data.type);

    // Supprimer l'ancien timeout si existant
    if (pressNotificationTimeout) {
        clearTimeout(pressNotificationTimeout);
        pressNotificationTimeout = null;
    }

    // Créer ou obtenir le container
    let container = document.getElementById('press-notification');
    if (!container) {
        container = document.createElement('div');
        container.id = 'press-notification';
        container.className = 'press-notification hidden';
        container.innerHTML = `
            <div class="press-notification-content">
                <div class="press-main-row">
                    <div class="press-logo-box">
                        <img src="assets/logo.png" alt="Logo" class="press-logo-img" />
                    </div>
                    <div class="press-text-box">
                        <div class="press-alert-title"></div>
                        <div class="press-alert-sub"></div>
                    </div>
                </div>
                <div class="press-progress-wrapper">
                    <div class="press-progress-fill"></div>
                </div>
            </div>
        `;
        document.body.appendChild(container);
    }

    // Mettre à jour le contenu
    const titleEl = container.querySelector('.press-alert-title');
    const subtitleEl = container.querySelector('.press-alert-sub');
    const progressFill = container.querySelector('.press-progress-fill');

    if (titleEl) titleEl.textContent = data.title || '';
    if (subtitleEl) subtitleEl.textContent = data.subtitle || '';

    // Afficher le container
    container.classList.remove('hidden');

    // Animer la barre de progression
    const duration = (data.duration || 30) * 1000;
    const startTime = Date.now();

    if (progressFill) {
        progressFill.style.width = '100%';
        progressFill.style.background = '#ff4444';

        const updateProgress = () => {
            if (!container || container.classList.contains('hidden')) return;

            const elapsed = Date.now() - startTime;
            const percent = Math.max(0, 100 - (elapsed / duration) * 100);

            progressFill.style.width = `${percent}%`;

            // Quand le temps est écoulé, passer au vert
            if (percent <= 0) {
                progressFill.style.background = '#00ff88';
                progressFill.style.boxShadow = '0 0 12px rgba(0, 255, 136, 0.6)';
                container.style.borderLeftColor = '#00ff88';
                if (subtitleEl) {
                    subtitleEl.textContent = 'DROP DISPONIBLE !';
                    subtitleEl.style.color = '#00ff88';
                }
            }

            if (elapsed < duration) {
                requestAnimationFrame(updateProgress);
            }
        };

        requestAnimationFrame(updateProgress);
    }

    // Cacher automatiquement après la durée
    pressNotificationTimeout = setTimeout(() => {
        hidePressNotification();
    }, duration);
}

/**
 * Cache la notification de press
 */
function hidePressNotification() {
    console.log('[REDZONE/PRESS] Masquage notification press');

    const container = document.getElementById('press-notification');
    if (container) {
        container.classList.add('hidden');
    }

    if (pressNotificationTimeout) {
        clearTimeout(pressNotificationTimeout);
        pressNotificationTimeout = null;
    }
}

// =====================================================
// KILLFEED - LOGIQUE
// =====================================================

const KILLFEED_MAX_ENTRIES = 6;
const KILLFEED_DISPLAY_TIME = 6000; // 6 secondes

/**
 * Ajoute une entrée au kill feed
 * @param {object} data - Données du kill (killerName, killerId, victimName, victimId)
 */
function addKillFeed(data) {
    console.log('[REDZONE/KILLFEED] Nouveau kill:', data);

    const container = document.getElementById('killfeed-container');
    if (!container) {
        console.error('[REDZONE/KILLFEED] Container non trouvé');
        return;
    }

    const killerName = data.killerName || 'Inconnu';
    const killerId = data.killerId || '?';
    const victimName = data.victimName || 'Inconnu';
    const victimId = data.victimId || '?';

    // Créer l'élément kill
    const killRow = document.createElement('div');
    killRow.className = 'kill-row';
    killRow.innerHTML = `
        <div class="killfeed-player-box killfeed-killer-box">
            <span class="killfeed-player-id">ID:${killerId}</span>
            <span class="killfeed-killer-name">${killerName}</span>
        </div>
        <div class="killfeed-action-tag">À TUÉ</div>
        <div class="killfeed-player-box">
            <span class="killfeed-victim-name">${victimName}</span>
            <span class="killfeed-player-id">ID:${victimId}</span>
        </div>
    `;

    // Ajouter en haut de la liste
    container.prepend(killRow);

    // Supprimer les entrées en excès
    while (container.children.length > KILLFEED_MAX_ENTRIES) {
        const lastChild = container.lastElementChild;
        if (lastChild) {
            lastChild.classList.add('killfeed-exit');
            setTimeout(() => {
                if (lastChild.parentNode) {
                    lastChild.remove();
                }
            }, 400);
        }
    }

    // Supprimer automatiquement après le délai
    setTimeout(() => {
        if (killRow.parentNode) {
            killRow.classList.add('killfeed-exit');
            setTimeout(() => {
                if (killRow.parentNode) {
                    killRow.remove();
                }
            }, 400);
        }
    }, KILLFEED_DISPLAY_TIME);
}

// =====================================================
// PLAYER INTERACT - LOGIQUE
// =====================================================

let playerInteractData = null;

function showPlayerInteract(data) {
    playerInteractData = data;
    const menu = document.getElementById('playerInteractMenu');
    const nameEl = document.getElementById('playerInteractName');
    const idEl = document.getElementById('playerInteractId');

    if (!menu) return;

    if (nameEl) nameEl.textContent = data.name || 'Joueur';
    if (idEl) idEl.textContent = '[ID: ' + (data.serverId || 0) + ']';

    menu.classList.remove('hidden');
}

function hidePlayerInteract() {
    const menu = document.getElementById('playerInteractMenu');
    if (menu) menu.classList.add('hidden');
    playerInteractData = null;
}

// Event listeners pour le menu interact
document.addEventListener('DOMContentLoaded', () => {
    const copyIdBtn = document.getElementById('piCopyId');
    const copyOutfitBtn = document.getElementById('piCopyOutfit');

    if (copyIdBtn) {
        copyIdBtn.addEventListener('click', () => {
            if (!playerInteractData) return;
            const id = String(playerInteractData.serverId || 0);
            // Fallback clipboard pour FiveM NUI (navigator.clipboard bloque)
            try {
                const ta = document.createElement('textarea');
                ta.value = id;
                ta.style.position = 'fixed';
                ta.style.left = '-9999px';
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                document.body.removeChild(ta);
            } catch(e) {}
            sendCallback('playerInteract:copyId', { serverId: playerInteractData.serverId });
            hidePlayerInteract();
        });
    }

    if (copyOutfitBtn) {
        copyOutfitBtn.addEventListener('click', () => {
            if (!playerInteractData) return;
            sendCallback('playerInteract:copyOutfit', { serverId: playerInteractData.serverId });
            hidePlayerInteract();
        });
    }
});

console.log('[REDZONE] Script JavaScript chargé');
