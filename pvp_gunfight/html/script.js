// ========================================
// PVP GUNFIGHT UI - SCRIPT.JS v5.0.0
// Architecture complète avec anti-spam
// ========================================

console.log('[PVP UI] 🚀 Initialisation v5.0.0 - Anti-Spam activé');

// ========================================
// 🔒 MODULE ANTI-SPAM
// ========================================
const AntiSpam = {
    cooldowns: {
        tab: 500,
        mode: 1500,
        stats_mode: 5000,
        leaderboard_mode: 5000,
        search: 3000,
        cancel_search: 3000,
        ready: 1500,
        invite: 2000,
        leave_group: 2000,
        kick: 1000,
        accept_invite: 1000,
        decline_invite: 500
    },
    
    lastActionTime: {},
    
    canPerformAction(actionType) {
        const now = Date.now();
        const cooldown = this.cooldowns[actionType] || 1000;
        const lastTime = this.lastActionTime[actionType] || 0;
        
        if (now - lastTime < cooldown) {
            const remaining = Math.ceil((cooldown - (now - lastTime)) / 1000);
            console.log(`[ANTI-SPAM] ⏳ Action "${actionType}" bloquée (${remaining}s restant)`);
            return false;
        }
        
        this.lastActionTime[actionType] = now;
        return true;
    },
    
    reset(actionType) {
        this.lastActionTime[actionType] = 0;
        console.log(`[ANTI-SPAM] ✅ Cooldown "${actionType}" réinitialisé`);
    },
    
    getRemainingTime(actionType) {
        const now = Date.now();
        const cooldown = this.cooldowns[actionType] || 1000;
        const lastTime = this.lastActionTime[actionType] || 0;
        const remaining = Math.max(0, cooldown - (now - lastTime));
        return Math.ceil(remaining / 1000);
    }
};

// ========================================
// 🌐 VARIABLES GLOBALES
// ========================================
const DEFAULT_AVATAR = 'https://cdn.discordapp.com/embed/avatars/0.png';

const RANKS = [
    { id: 1, name: "Bronze", min: 0, max: 999, color: "#cd7f32", emoji: "🥉" },
    { id: 2, name: "Argent", min: 1000, max: 1499, color: "#c0c0c0", emoji: "⚪" },
    { id: 3, name: "Or", min: 1500, max: 1999, color: "#ffd700", emoji: "🥇" },
    { id: 4, name: "Platine", min: 2000, max: 2499, color: "#4da6ff", emoji: "💎" },
    { id: 5, name: "Émeraude", min: 2500, max: 2999, color: "#50c878", emoji: "💚" },
    { id: 6, name: "Diamant", min: 3000, max: 3499, color: "#b9f2ff", emoji: "💠" },
    { id: 7, name: "Master 3", min: 3500, max: 3999, color: "#ff6600", emoji: "🔥" },
    { id: 8, name: "Master 2", min: 4000, max: 4499, color: "#ff3300", emoji: "🔥" },
    { id: 9, name: "Master 1", min: 4500, max: 99999, color: "#ff0000", emoji: "👑" }
];

const KILLFEED_CONFIG = {
    MAX_ITEMS: 6,
    DURATION: 6000,
    FADE_OUT_DURATION: 400
};

const ANIMATION_CONFIG = {
    ROUND_END_DELAY: 1500,
    COMBAT_OVERLAY_DURATION: 1000,
    MATCH_END_DURATION: 1500
};

// État de l'application
let appState = {
    // UI
    isUIOpen: false,
    isSearching: false,
    isInMatch: false,
    
    // Groupe
    currentGroup: null,
    selectedMode: null,
    selectedPlayers: 1,
    isReady: false,
    myAvatar: DEFAULT_AVATAR,
    
    // Stats
    currentStatsMode: '1v1',
    currentLeaderboardMode: '1v1',
    allModeStats: null,
    
    // Queue
    queueStats: { '1v1': 0, '2v2': 0, '3v3': 0, '4v4': 0 },
    
    // Invitations
    pendingInvitations: [],
    
    // Killfeed
    killfeedItems: [],
    
    // Timers
    roundEndTimer: null,
    searchStartTime: 0
};

// ========================================
// 🛠️ UTILITAIRES
// ========================================
function getRankByElo(elo) {
    for (const rank of RANKS) {
        if (elo >= rank.min && elo <= rank.max) {
            return rank;
        }
    }
    return RANKS[5];
}

function sanitizeName(name) {
    if (!name || name === '') return 'Unknown';
    const maxLength = 15;
    if (name.length > maxLength) {
        return name.substring(0, maxLength - 3) + '...';
    }
    return name;
}

function getResourceName() {
    if (window.location.protocol === 'file:') {
        return 'pvp_gunfight';
    }
    
    const nuiMatch = window.location.href.match(/nui:\/\/([^\/]+)\//);
    if (nuiMatch) {
        return nuiMatch[1];
    }
    
    return 'pvp_gunfight';
}

function makeRequest(endpoint, data = {}) {
    return fetch(`https://${getResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(err => {
        console.error(`[ERROR] Requête ${endpoint} échouée:`, err);
    });
}

// ========================================
// 📡 MESSAGES LUA → JS
// ========================================
window.addEventListener('message', function(event) {
    const data = event.data;
    
    const messageHandlers = {
        openUI: () => openUI(data.isSearching || false),
        closeUI: () => closeUIVisual(),
        updateGroup: () => updateGroupDisplay(data.group),
        showInvite: () => addInvitationToQueue(data.inviterName, data.inviterId, data.inviterAvatar),
        searchStarted: () => showSearchStatus(data.mode),
        updateSearchTimer: () => updateSearchTimer(data.elapsed),
        matchFound: () => {
            hideSearchStatus();
            appState.isInMatch = true;
            AntiSpam.reset('search');
        },
        searchCancelled: () => {
            hideSearchStatus();
            enableReadyButton();
            AntiSpam.reset('search');
        },
        showRoundStart: () => showRoundStart(data.round),
        showCountdown: () => showCountdown(data.number),
        showGo: () => showGo(),
        showRoundEnd: () => showRoundEnd(data.winner, data.score, data.playerTeam, data.isVictory),
        showMatchEnd: () => {
            showMatchEnd(data.victory, data.score, data.playerTeam);
            appState.isInMatch = false;
        },
        updateScore: () => updateScoreHUD(data.score, data.round),
        showScoreHUD: () => showScoreHUD(data.score, data.round),
        hideScoreHUD: () => hideScoreHUD(),
        closeInvitationsPanel: () => hideInvitationsPanel(),
        updateQueueStats: () => {
            appState.queueStats = data.stats || appState.queueStats;
            updateQueueDisplay();
        },
        showKillfeed: () => addKillfeed(data.killerName, data.victimName, data.weapon, data.isHeadshot)
    };
    
    const handler = messageHandlers[data.action];
    if (handler) {
        handler();
    }
});

// ========================================
// 🎨 UI - OUVERTURE/FERMETURE
// ========================================
function openUI(isSearching = false) {
    document.getElementById('container').classList.remove('hidden');
    appState.isUIOpen = true;
    
    if (isSearching) {
        showSearchScreen();
    }
    
    requestQueueStats();
    loadStatsWithCallback(() => loadGroupInfo());
}

function closeUIVisual() {
    document.getElementById('container').classList.add('hidden');
    appState.isUIOpen = false;
}

function closeUI() {
    makeRequest('closeUI');
}

function showSearchScreen() {
    const mainMenu = document.querySelector('.lobby-content');
    if (mainMenu) {
        mainMenu.style.display = 'none';
    }
    
    const searchStatus = document.getElementById('search-status');
    if (searchStatus) {
        searchStatus.classList.remove('hidden');
    }
}

// ========================================
// 📊 STATS QUEUE
// ========================================
function requestQueueStats() {
    makeRequest('getQueueStats')
        .then(resp => resp.json())
        .then(stats => {
            appState.queueStats = stats;
            updateQueueDisplay();
        })
        .catch(() => {});
}

function updateQueueDisplay() {
    const modes = ['1v1', '2v2', '3v3', '4v4'];
    
    modes.forEach(mode => {
        const queueInfo = document.getElementById(`queue-${mode}`);
        const queueCount = queueInfo?.querySelector('.queue-count');
        
        if (queueInfo && queueCount) {
            const count = appState.queueStats[mode] || 0;
            
            if (queueCount.textContent !== count.toString()) {
                queueCount.textContent = count;
                
                if (count > 0) {
                    queueInfo.classList.add('has-players', 'animate-in');
                    setTimeout(() => queueInfo.classList.remove('animate-in'), 300);
                } else {
                    queueInfo.classList.remove('has-players');
                }
            }
        }
    });
}

// ========================================
// 🔔 SYSTÈME D'INVITATIONS
// ========================================
function addInvitationToQueue(inviterName, inviterId, inviterAvatar) {
    const exists = appState.pendingInvitations.find(inv => inv.inviterId === inviterId);
    if (exists) return;
    
    appState.pendingInvitations.push({
        inviterName,
        inviterId,
        inviterAvatar: inviterAvatar || DEFAULT_AVATAR,
        timestamp: Date.now()
    });
    
    updateNotificationBadge();
    
    setTimeout(() => removeInvitation(inviterId), 30000);
}

function removeInvitation(inviterId) {
    appState.pendingInvitations = appState.pendingInvitations.filter(inv => inv.inviterId !== inviterId);
    updateNotificationBadge();
    
    if (!document.getElementById('invitations-panel').classList.contains('hidden')) {
        renderInvitationsPanel();
    }
}

function updateNotificationBadge() {
    const badge = document.getElementById('notification-count');
    const count = appState.pendingInvitations.length;
    
    if (count > 0) {
        badge.textContent = count;
        badge.classList.remove('hidden');
    } else {
        badge.classList.add('hidden');
    }
}

function showInvitationsPanel() {
    document.getElementById('invitations-panel').classList.remove('hidden');
    renderInvitationsPanel();
}

function hideInvitationsPanel() {
    document.getElementById('invitations-panel').classList.add('hidden');
}

function renderInvitationsPanel() {
    const list = document.getElementById('invitations-list');
    const noInvitations = document.getElementById('no-invitations');
    
    list.innerHTML = '';
    
    if (appState.pendingInvitations.length === 0) {
        noInvitations.classList.remove('hidden');
        return;
    }
    
    noInvitations.classList.add('hidden');
    
    appState.pendingInvitations.forEach(invitation => {
        const item = document.createElement('div');
        item.className = 'invitation-item';
        item.innerHTML = `
            <div class="invitation-avatar">
                <img src="${invitation.inviterAvatar}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
            </div>
            <div class="invitation-info">
                <div class="invitation-from">${invitation.inviterName}</div>
                <div class="invitation-message">Vous invite à rejoindre son groupe</div>
            </div>
            <div class="invitation-actions">
                <button class="btn-accept-inv" data-inviter-id="${invitation.inviterId}">✓ Accepter</button>
                <button class="btn-decline-inv" data-inviter-id="${invitation.inviterId}">✕ Refuser</button>
            </div>
        `;
        list.appendChild(item);
    });
    
    document.querySelectorAll('.btn-accept-inv').forEach(btn => {
        btn.addEventListener('click', function() {
            if (!AntiSpam.canPerformAction('accept_invite')) return;
            const inviterId = parseInt(this.getAttribute('data-inviter-id'));
            makeRequest('acceptInvite', { inviterId });
            removeInvitation(inviterId);
            renderInvitationsPanel();
        });
    });
    
    document.querySelectorAll('.btn-decline-inv').forEach(btn => {
        btn.addEventListener('click', function() {
            if (!AntiSpam.canPerformAction('decline_invite')) return;
            const inviterId = parseInt(this.getAttribute('data-inviter-id'));
            makeRequest('declineInvite', {});
            removeInvitation(inviterId);
            renderInvitationsPanel();
        });
    });
}

// ========================================
// 👥 GESTION DU GROUPE
// ========================================
function loadGroupInfo() {
    makeRequest('getGroupInfo')
        .then(resp => resp.json())
        .then(groupInfo => updateGroupDisplay(groupInfo))
        .catch(() => updateGroupDisplay(null));
}

function updateGroupDisplay(group) {
    appState.currentGroup = group;
    
    const slots = document.querySelectorAll('.player-slot');
    const readyBtn = document.getElementById('ready-btn');
    const leaveGroupBtn = document.getElementById('leave-group-btn');
    
    // Réinitialiser tous les slots
    for (let i = 0; i < slots.length; i++) {
        const slot = slots[i];
        slot.className = 'player-slot empty-slot';
        
        if (appState.selectedMode && i < appState.selectedPlayers) {
            slot.classList.remove('locked');
            slot.innerHTML = `
                <div class="empty-content">
                    <div class="add-icon">+</div>
                    <div class="slot-text">Cliquez pour inviter</div>
                </div>
            `;
            slot.onclick = () => openInvitePopup(i);
        } else if (i > 0) {
            slot.classList.add('locked');
            slot.innerHTML = `
                <div class="empty-content">
                    <div class="add-icon">+</div>
                    <div class="slot-text">${appState.selectedMode ? 'Non disponible' : 'Sélectionnez un mode'}</div>
                </div>
            `;
            slot.onclick = null;
        }
    }
    
    // Si pas de groupe (solo)
    if (!group || !group.members || group.members.length === 0) {
        const firstSlot = slots[0];
        firstSlot.className = 'player-slot host-slot';
        firstSlot.innerHTML = `
            <div class="slot-content">
                <div class="player-avatar">
                    <img src="${appState.myAvatar}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
                </div>
                <div class="player-info">
                    <div class="player-name">Vous</div>
                    <div class="player-status">
                        <span class="host-badge">👑 Hôte</span>
                    </div>
                </div>
                <div class="player-ready">
                    <div class="ready-indicator"></div>
                </div>
            </div>
        `;
        
        appState.isReady = false;
        readyBtn.classList.remove('ready');
        document.getElementById('ready-text').textContent = 'SE METTRE PRÊT';
        leaveGroupBtn.classList.add('hidden');
        updateSearchButton();
        return;
    }
    
    // Déterminer les infos du joueur actuel
    let isLeader = false;
    for (let i = 0; i < group.members.length; i++) {
        if (group.members[i].isYou) {
            isLeader = group.members[i].isLeader;
            appState.isReady = group.members[i].isReady;
            appState.myAvatar = group.members[i].avatar || DEFAULT_AVATAR;
            break;
        }
    }
    
    // Afficher les membres
    group.members.forEach((member, index) => {
        if (index >= slots.length) return;
        
        const slot = slots[index];
        slot.className = 'player-slot';
        
        if (member.isLeader) slot.classList.add('host-slot');
        if (member.isReady) slot.classList.add('ready');
        
        const canKick = isLeader && !member.isLeader && !member.isYou;
        const avatarUrl = member.avatar || DEFAULT_AVATAR;
        
        slot.innerHTML = `
            <div class="slot-content">
                <div class="player-avatar">
                    <img src="${avatarUrl}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
                </div>
                <div class="player-info">
                    <div class="player-name">${member.name}${member.isYou ? ' (Vous)' : ''}</div>
                    <div class="player-status">
                        ${member.isLeader ? '<span class="host-badge">👑 Hôte</span>' : '<span class="player-id">ID: ' + member.id + '</span>'}
                    </div>
                </div>
                <div class="player-ready">
                    <div class="ready-indicator ${member.isReady ? 'ready' : ''}"></div>
                    ${canKick ? '<button class="btn-kick" onclick="kickPlayer(' + member.id + ')">KICK</button>' : ''}
                </div>
            </div>
        `;
        slot.onclick = null;
    });
    
    // Mettre à jour le bouton ready
    if (appState.isReady) {
        readyBtn.classList.add('ready');
        document.getElementById('ready-text').textContent = '✓ PRÊT';
    } else {
        readyBtn.classList.remove('ready');
        document.getElementById('ready-text').textContent = 'SE METTRE PRÊT';
    }
    
    // Afficher le bouton quitter si nécessaire
    if (group.members.length > 1) {
        leaveGroupBtn.classList.remove('hidden');
    } else {
        leaveGroupBtn.classList.add('hidden');
    }
    
    // Désactiver ready si en recherche
    const searchStatus = document.getElementById('search-status');
    const isSearchingNow = searchStatus && !searchStatus.classList.contains('hidden');
    
    if (isSearchingNow) {
        disableReadyButton();
    } else {
        enableReadyButton();
    }
    
    updateSearchButton();
}

function enableReadyButton() {
    const readyBtn = document.getElementById('ready-btn');
    if (readyBtn) {
        readyBtn.disabled = false;
        readyBtn.style.opacity = '1';
        readyBtn.style.cursor = 'pointer';
        readyBtn.title = '';
    }
}

function disableReadyButton() {
    const readyBtn = document.getElementById('ready-btn');
    if (readyBtn) {
        readyBtn.disabled = true;
        readyBtn.style.opacity = '0.5';
        readyBtn.style.cursor = 'not-allowed';
        readyBtn.title = 'Annulez d\'abord la recherche';
    }
}

function updatePlayerSlots() {
    const slots = document.querySelectorAll('.player-slot');
    
    slots.forEach((slot, index) => {
        if (index === 0) return;
        
        if (index < appState.selectedPlayers) {
            slot.classList.remove('locked');
            
            if (slot.classList.contains('empty-slot')) {
                const slotText = slot.querySelector('.slot-text');
                if (slotText) {
                    slotText.textContent = 'Cliquez pour inviter';
                }
                slot.onclick = () => openInvitePopup(index);
            }
        } else {
            slot.classList.add('locked');
            
            if (slot.classList.contains('empty-slot')) {
                const slotText = slot.querySelector('.slot-text');
                if (slotText) {
                    slotText.textContent = 'Non disponible';
                }
                slot.onclick = null;
            }
        }
    });
}

function openInvitePopup(slotIndex) {
    document.getElementById('invite-player-popup').classList.remove('hidden');
}

function kickPlayer(targetId) {
    if (!AntiSpam.canPerformAction('kick')) return;
    makeRequest('kickPlayer', { targetId });
}

// ========================================
// 🔍 RECHERCHE DE PARTIE
// ========================================
function updateSearchButton() {
    const searchBtn = document.getElementById('search-btn');
    const searchText = document.getElementById('search-text');
    
    if (!appState.selectedMode) {
        searchBtn.disabled = true;
        searchText.textContent = 'SÉLECTIONNEZ UN MODE';
        return;
    }
    
    if (!appState.currentGroup || !appState.currentGroup.members) {
        searchBtn.disabled = true;
        searchText.textContent = `IL FAUT ${appState.selectedPlayers} JOUEUR(S)`;
        return;
    }
    
    let isLeader = false;
    for (let i = 0; i < appState.currentGroup.members.length; i++) {
        if (appState.currentGroup.members[i].isYou && appState.currentGroup.members[i].isLeader) {
            isLeader = true;
            break;
        }
    }
    
    if (!isLeader) {
        searchBtn.disabled = true;
        searchText.textContent = 'SEUL L\'HÔTE PEUT LANCER';
        return;
    }
    
    const allReady = appState.currentGroup.members.every(m => m.isReady);
    const correctSize = appState.currentGroup.members.length === appState.selectedPlayers;
    
    if (!correctSize) {
        searchBtn.disabled = true;
        searchText.textContent = `IL FAUT ${appState.selectedPlayers} JOUEUR(S)`;
    } else if (!allReady) {
        searchBtn.disabled = true;
        searchText.textContent = 'TOUS LES JOUEURS DOIVENT ÊTRE PRÊTS';
    } else {
        searchBtn.disabled = false;
        searchText.textContent = 'RECHERCHER UNE PARTIE';
    }
}

function showSearchStatus(mode) {
    appState.isSearching = true;
    appState.searchStartTime = Date.now();
    
    document.getElementById('search-btn').style.display = 'none';
    document.getElementById('search-status').classList.remove('hidden');
    document.getElementById('search-mode-display').textContent = mode.toUpperCase();
}

function hideSearchStatus() {
    appState.isSearching = false;
    
    document.getElementById('search-status').classList.add('hidden');
    document.getElementById('search-btn').style.display = 'flex';
}

function updateSearchTimer(elapsed) {
    const minutes = Math.floor(elapsed / 60);
    const seconds = elapsed % 60;
    document.getElementById('search-timer').textContent = 
        `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

// ========================================
// 📈 STATISTIQUES
// ========================================
function loadStatsWithCallback(callback) {
    makeRequest('getStats')
        .then(resp => resp.json())
        .then(stats => {
            if (stats?.avatar) {
                appState.myAvatar = stats.avatar;
                const statsAvatarEl = document.getElementById('stats-avatar');
                if (statsAvatarEl) {
                    statsAvatarEl.src = appState.myAvatar;
                }
            }
            if (callback) callback();
        })
        .catch(() => {
            if (callback) callback();
        });
}

function loadAllModeStats() {
    makeRequest('getPlayerAllModeStats')
        .then(resp => resp.json())
        .then(data => {
            appState.allModeStats = data;
            
            if (data?.avatar) {
                appState.myAvatar = data.avatar;
                document.getElementById('stats-avatar').src = data.avatar;
            }
            
            if (data?.name) {
                document.getElementById('stats-player-name').textContent = data.name;
            }
            
            if (data?.modes?.[appState.currentStatsMode]) {
                displayModeStats(data.modes[appState.currentStatsMode]);
            }
        })
        .catch(() => {});
}

function loadStatsByMode(mode) {
    makeRequest('getPlayerStatsByMode', { mode })
        .then(resp => resp.json())
        .then(stats => displayModeStats(stats))
        .catch(() => {});
}

function displayModeStats(stats) {
    if (!stats) return;
    
    const elo = stats.elo || 0;
    const kills = stats.kills || 0;
    const deaths = stats.deaths || 0;
    const wins = stats.wins || 0;
    const losses = stats.losses || 0;
    const matches = stats.matches_played || 0;
    const winStreak = stats.win_streak || 0;
    const bestWinStreak = stats.best_win_streak || 0;
    const bestElo = stats.best_elo || elo;
    
    const ratio = deaths > 0 ? (kills / deaths).toFixed(2) : kills.toFixed(2);
    const winrate = matches > 0 ? Math.round((wins / matches) * 100) : 0;
    const rank = getRankByElo(elo);
    
    document.getElementById('stat-elo').textContent = elo;
    document.getElementById('stat-kills').textContent = kills;
    document.getElementById('stat-deaths').textContent = deaths;
    document.getElementById('stat-ratio').textContent = ratio;
    document.getElementById('stat-matches').textContent = matches;
    document.getElementById('stat-wins').textContent = wins;
    document.getElementById('stat-losses').textContent = losses;
    document.getElementById('stat-winrate').textContent = winrate + '%';
    document.getElementById('stat-streak').textContent = winStreak;
    document.getElementById('stat-best-streak').textContent = bestWinStreak;
    document.getElementById('stat-best-elo').textContent = bestElo;
    
    const rankEl = document.getElementById('stat-rank');
    if (rankEl) {
        rankEl.textContent = rank.name;
        rankEl.style.color = rank.color;
    }
}

// ========================================
// 🏆 LEADERBOARD
// ========================================
function loadLeaderboardByMode(mode) {
    makeRequest('getLeaderboardByMode', { mode })
        .then(resp => resp.json())
        .then(leaderboard => displayLeaderboard(leaderboard))
        .catch(() => displayLeaderboard([]));
}

function displayLeaderboard(leaderboard) {
    const tbody = document.getElementById('leaderboard-body');
    tbody.innerHTML = '';
    
    if (leaderboard?.length > 0) {
        leaderboard.forEach((player, index) => {
            const row = document.createElement('tr');
            const kills = player.kills || 0;
            const deaths = player.deaths || 0;
            const wins = player.wins || 0;
            const matches = player.matches_played || 0;
            const ratio = deaths > 0 ? (kills / deaths).toFixed(2) : kills.toFixed(2);
            const winrate = matches > 0 ? Math.round((wins / matches) * 100) : 0;
            const avatarUrl = player.avatar || DEFAULT_AVATAR;
            const rank = getRankByElo(player.elo);
            
            let rankBadge = '';
            if (index === 0) rankBadge = '<span class="rank-badge gold">🥇</span>';
            else if (index === 1) rankBadge = '<span class="rank-badge silver">🥈</span>';
            else if (index === 2) rankBadge = '<span class="rank-badge bronze">🥉</span>';
            
            row.innerHTML = `
                <td class="rank">${rankBadge || '#' + (index + 1)}</td>
                <td class="player-cell">
                    <img class="leaderboard-avatar" src="${avatarUrl}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
                    <div class="player-lb-info">
                        <span class="player-name-lb">${player.name}</span>
                        <span class="player-rank-lb" style="color: ${rank.color}">${rank.name}</span>
                    </div>
                </td>
                <td class="elo-cell">${player.elo}</td>
                <td>${ratio}</td>
                <td>${wins}</td>
                <td>${winrate}%</td>
            `;
            
            tbody.appendChild(row);
        });
    } else {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #5B5A56;">Aucune donnée disponible</td></tr>';
    }
}

// ========================================
// ⚔️ ANIMATIONS DE COMBAT
// ========================================
function showRoundStart(roundNumber) {
    const overlay = document.getElementById('combat-overlay');
    const message = document.getElementById('combat-message');
    const subtitle = document.getElementById('combat-subtitle');
    
    overlay.classList.remove('hidden');
    message.textContent = `ROUND ${roundNumber}`;
    subtitle.textContent = 'Préparez-vous';
    
    setTimeout(() => overlay.classList.add('hidden'), ANIMATION_CONFIG.COMBAT_OVERLAY_DURATION);
}

function showCountdown(number) {
    const overlay = document.getElementById('combat-overlay');
    const message = document.getElementById('combat-message');
    const subtitle = document.getElementById('combat-subtitle');
    
    overlay.classList.remove('hidden');
    message.textContent = number;
    subtitle.textContent = '';
    
    setTimeout(() => overlay.classList.add('hidden'), ANIMATION_CONFIG.COMBAT_OVERLAY_DURATION);
}

function showGo() {
    const overlay = document.getElementById('combat-overlay');
    const message = document.getElementById('combat-message');
    const subtitle = document.getElementById('combat-subtitle');
    
    overlay.classList.remove('hidden');
    message.textContent = 'GO!';
    subtitle.textContent = 'Combattez !';
    
    setTimeout(() => overlay.classList.add('hidden'), ANIMATION_CONFIG.COMBAT_OVERLAY_DURATION);
}

function showRoundEnd(winningTeam, score, playerTeam, isVictory) {
    if (appState.roundEndTimer) {
        clearTimeout(appState.roundEndTimer);
        appState.roundEndTimer = null;
    }
    
    appState.roundEndTimer = setTimeout(() => {
        const overlay = document.getElementById('round-end-overlay');
        const title = document.getElementById('round-end-title');
        const subtitle = document.getElementById('round-end-subtitle');
        
        if (isVictory) {
            title.textContent = 'VICTOIRE';
            title.className = 'round-end-title victory';
            subtitle.textContent = 'Manche remportée !';
        } else {
            title.textContent = 'DÉFAITE';
            title.className = 'round-end-title defeat';
            subtitle.textContent = 'Manche perdue';
        }
        
        document.getElementById('round-score-team1').textContent = score.team1;
        document.getElementById('round-score-team2').textContent = score.team2;
        
        overlay.classList.remove('hidden');
        
        setTimeout(() => {
            overlay.classList.add('hidden');
        }, 1500);
        
        appState.roundEndTimer = null;
    }, ANIMATION_CONFIG.ROUND_END_DELAY);
}

function showMatchEnd(victory, score, playerTeam) {
    clearAllKillfeeds();
    
    if (appState.roundEndTimer) {
        clearTimeout(appState.roundEndTimer);
        appState.roundEndTimer = null;
    }
    
    const overlay = document.getElementById('match-end-overlay');
    const result = document.getElementById('match-end-result');
    const message = document.getElementById('match-end-message');
    
    if (victory) {
        result.textContent = 'VICTOIRE';
        result.className = 'match-end-result victory';
        message.textContent = 'Félicitations ! Vous avez gagné le match ! 🎉';
    } else {
        result.textContent = 'DÉFAITE';
        result.className = 'match-end-result defeat';
        message.textContent = 'Dommage... Vous avez perdu le match. Réessayez !';
    }
    
    document.getElementById('final-score-team1').textContent = score.team1;
    document.getElementById('final-score-team2').textContent = score.team2;
    
    overlay.classList.remove('hidden');
    setTimeout(() => overlay.classList.add('hidden'), ANIMATION_CONFIG.MATCH_END_DURATION);
}

// ========================================
// 🎯 HUD DE SCORE
// ========================================
function showScoreHUD(score, round) {
    updateScoreHUD(score, round);
    document.getElementById('score-hud').classList.remove('hidden');
}

function hideScoreHUD() {
    document.getElementById('score-hud').classList.add('hidden');
}

function updateScoreHUD(score, round) {
    const team1El = document.getElementById('team1-score');
    const team2El = document.getElementById('team2-score');
    const roundEl = document.getElementById('current-round-display');

    // Animation si le score a changé
    const oldScore1 = parseInt(team1El.textContent) || 0;
    const oldScore2 = parseInt(team2El.textContent) || 0;

    team1El.textContent = score.team1;
    team2El.textContent = score.team2;
    roundEl.textContent = round;

    // Pulse animation sur le score qui a changé
    if (score.team1 > oldScore1) {
        team1El.classList.add('score-update');
        setTimeout(() => team1El.classList.remove('score-update'), 500);
    }
    if (score.team2 > oldScore2) {
        team2El.classList.add('score-update');
        setTimeout(() => team2El.classList.remove('score-update'), 500);
    }
}

// ========================================
// 💀 KILLFEED
// ========================================
// Parse le format "NomJoueur [ID]" pour extraire nom et ID
function parsePlayerName(fullName) {
    if (!fullName) return { name: 'Inconnu', id: '?' };
    const match = fullName.match(/^(.+?)\s*\[(\d+)\]$/);
    if (match) {
        return { name: match[1].trim(), id: match[2] };
    }
    return { name: fullName, id: '?' };
}

function addKillfeed(killerName, victimName, weapon, isHeadshot) {
    const container = document.getElementById('killfeed-container');
    if (!container) return;

    const item = document.createElement('div');
    item.className = 'killfeed-item';

    // Parser les noms pour extraire les vrais IDs FiveM
    const killer = parsePlayerName(killerName);
    const victim = parsePlayerName(victimName);

    if (isHeadshot) {
        item.classList.add('headshot');
    }

    if (!killerName) {
        // Suicide
        item.classList.add('suicide');
        item.innerHTML = `
            <div class="killfeed-player-box">
                <span class="killfeed-player-id">ID:${victim.id}</span>
                <span class="killfeed-victim">${sanitizeName(victim.name)}</span>
            </div>
            <div class="killfeed-action-tag">MORT</div>
        `;
    } else {
        // Kill normal
        item.innerHTML = `
            <div class="killfeed-player-box killer-box">
                <span class="killfeed-player-id">ID:${killer.id}</span>
                <span class="killfeed-killer">${sanitizeName(killer.name)}</span>
            </div>
            <div class="killfeed-action-tag">À TUÉ</div>
            <div class="killfeed-player-box">
                <span class="killfeed-player-id">ID:${victim.id}</span>
                <span class="killfeed-victim">${sanitizeName(victim.name)}</span>
            </div>
            ${isHeadshot ? '<span class="killfeed-headshot-badge">HEADSHOT</span>' : ''}
        `;
    }

    // Ajouter en haut (prepend) pour que les nouveaux kills apparaissent en premier
    container.prepend(item);

    appState.killfeedItems.push({
        element: item,
        timestamp: Date.now()
    });

    if (appState.killfeedItems.length > KILLFEED_CONFIG.MAX_ITEMS) {
        removeOldestKillfeed();
    }

    setTimeout(() => removeKillfeedItem(item), KILLFEED_CONFIG.DURATION);
}

function removeOldestKillfeed() {
    if (appState.killfeedItems.length === 0) return;
    const oldest = appState.killfeedItems.shift();
    removeKillfeedItem(oldest.element);
}

function removeKillfeedItem(element) {
    if (!element || !element.parentNode) return;
    element.classList.add('fade-out');
    setTimeout(() => {
        if (element.parentNode) {
            element.remove();
        }
        appState.killfeedItems = appState.killfeedItems.filter(item => item.element !== element);
    }, KILLFEED_CONFIG.FADE_OUT_DURATION);
}

function clearAllKillfeeds() {
    appState.killfeedItems.forEach(item => {
        if (item.element?.parentNode) {
            item.element.remove();
        }
    });
    appState.killfeedItems = [];
}

// ========================================
// 🎮 EVENT LISTENERS
// ========================================
function initializeEventListeners() {
    // Fermeture UI
    document.getElementById('close-button').addEventListener('click', closeUI);
    
    // ESC pour fermer
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            const invitationsPanel = document.getElementById('invitations-panel');
            
            if (!invitationsPanel.classList.contains('hidden')) {
                hideInvitationsPanel();
                return;
            }
            
            const container = document.getElementById('container');
            if (!container.classList.contains('hidden')) {
                closeUI();
            }
        }
    });
    
    // Invitations
    document.getElementById('notification-bell').addEventListener('click', function() {
        const panel = document.getElementById('invitations-panel');
        if (panel.classList.contains('hidden')) {
            showInvitationsPanel();
        } else {
            hideInvitationsPanel();
        }
    });
    
    document.getElementById('close-invitations').addEventListener('click', hideInvitationsPanel);
    
    // Onglets
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            if (!AntiSpam.canPerformAction('tab')) return;
            
            const tabName = this.getAttribute('data-tab');
            
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            
            this.classList.add('active');
            document.getElementById(tabName + '-tab').classList.add('active');
            
            if (tabName === 'stats') {
                loadAllModeStats();
            } else if (tabName === 'leaderboard') {
                loadLeaderboardByMode(appState.currentLeaderboardMode);
            } else if (tabName === 'lobby') {
                loadGroupInfo();
                requestQueueStats();
            }
        });
    });
    
    // Sélection mode
    document.querySelectorAll('.mode-card').forEach(card => {
        card.addEventListener('click', function() {
            if (!AntiSpam.canPerformAction('mode')) return;
            
            const mode = this.getAttribute('data-mode');
            const players = parseInt(this.getAttribute('data-players'));
            
            document.querySelectorAll('.mode-card').forEach(c => c.classList.remove('selected'));
            this.classList.add('selected');
            
            appState.selectedMode = mode;
            appState.selectedPlayers = players;
            
            document.getElementById('mode-display').textContent = mode.toUpperCase();
            
            updatePlayerSlots();
            updateSearchButton();
        });
    });
    
    // Invitation popup
    document.getElementById('confirm-invite-btn').addEventListener('click', function() {
        if (!AntiSpam.canPerformAction('invite')) return;
        
        const input = document.getElementById('invite-input');
        const targetId = parseInt(input.value);
        
        if (!targetId || targetId < 1) return;
        
        makeRequest('invitePlayer', { targetId });
        
        input.value = '';
        document.getElementById('invite-player-popup').classList.add('hidden');
    });
    
    document.getElementById('cancel-invite-btn').addEventListener('click', function() {
        document.getElementById('invite-input').value = '';
        document.getElementById('invite-player-popup').classList.add('hidden');
    });
    
    // Ready
    document.getElementById('ready-btn').addEventListener('click', function() {
        if (!AntiSpam.canPerformAction('ready')) return;
        
        const searchStatus = document.getElementById('search-status');
        const isSearching = searchStatus && !searchStatus.classList.contains('hidden');
        
        if (isSearching) return;
        
        makeRequest('toggleReady');
    });
    
    // Quitter groupe
    document.getElementById('leave-group-btn').addEventListener('click', function() {
        if (!AntiSpam.canPerformAction('leave_group')) return;
        makeRequest('leaveGroup');
    });
    
    // Recherche
    document.getElementById('search-btn').addEventListener('click', function() {
        if (this.disabled) return;
        
        if (!AntiSpam.canPerformAction('search')) {
            const remaining = AntiSpam.getRemainingTime('search');
            console.log(`⏳ Veuillez attendre ${remaining}s avant de lancer une nouvelle recherche`);
            return;
        }
        
        makeRequest('joinQueue', { mode: appState.selectedMode });
    });
    
    // Annuler recherche
    document.getElementById('cancel-search-btn').addEventListener('click', function() {
        if (!AntiSpam.canPerformAction('cancel_search')) return;
        makeRequest('cancelSearch');
    });
    
    // Stats par mode
    document.querySelectorAll('.stats-mode-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            if (!AntiSpam.canPerformAction('stats_mode')) return;
            
            const mode = this.getAttribute('data-stats-mode');
            
            document.querySelectorAll('.stats-mode-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            appState.currentStatsMode = mode;
            
            document.getElementById('current-stats-mode-title').textContent = `Statistiques ${mode.toUpperCase()}`;
            
            if (appState.allModeStats?.modes?.[mode]) {
                displayModeStats(appState.allModeStats.modes[mode]);
            } else {
                loadStatsByMode(mode);
            }
        });
    });
    
    // Leaderboard par mode
    document.querySelectorAll('.lb-mode-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            if (!AntiSpam.canPerformAction('leaderboard_mode')) return;
            
            const mode = this.getAttribute('data-lb-mode');
            
            document.querySelectorAll('.lb-mode-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            appState.currentLeaderboardMode = mode;
            loadLeaderboardByMode(mode);
        });
    });
}

// ========================================
// 🚀 INITIALISATION
// ========================================
document.addEventListener('DOMContentLoaded', function() {
    initializeEventListeners();
    console.log('[PVP UI] ✅ Tous les event listeners initialisés');
});

console.log('[PVP UI] ✅ v5.0.0 chargée - Prête à l\'emploi');
console.log('[PVP UI] 🔒 Anti-Spam: Tab=500ms | Mode=300ms | Stats/LB=500ms | Recherche=3s | Actions=1-2s');