/**
 * Quick Transfer - Clic droit pour transferer rapidement les items
 * Compatible avec qs-inventory
 */

console.log('[QuickTransfer] Script charge');

(function() {
    'use strict';

    function log(msg, data) {
        if (data !== undefined) {
            console.log('[QuickTransfer] ' + msg, data);
        } else {
            console.log('[QuickTransfer] ' + msg);
        }
    }

    // Fonction pour obtenir le nom de l'autre inventaire
    function getOtherInventoryName() {
        // 1. Essayer de lire l'attribut data-inventory du conteneur
        var dataInv = $('.other-inventory').attr('data-inventory');
        if (dataInv && dataInv !== 'other') {
            log('data-inventory attr: ' + dataInv);
            return dataInv;
        }

        // 2. Essayer otherLabel (variable globale de qs-inventory)
        if (typeof otherLabel !== 'undefined' && otherLabel && otherLabel !== '') {
            log('otherLabel: ' + otherLabel);
            return otherLabel;
        }

        // 3. Essayer InventoryOption
        if (typeof InventoryOption !== 'undefined' && InventoryOption && InventoryOption !== '0, 0, 0') {
            log('InventoryOption: ' + InventoryOption);
            return InventoryOption;
        }

        // 4. Fallback: essayer de lire depuis le label affiché
        var label = $('#other-inv-label').text().trim();
        if (label) {
            log('Label text: ' + label);
            return label;
        }

        log('Using default: other');
        return 'other';
    }

    // Fonction pour verifier si l'autre inventaire est ouvert
    function isOtherInventoryOpen() {
        var $otherContainer = $('.oth-inv-container');
        if (!$otherContainer.is(':visible')) return false;
        var $otherLabel = $('#other-inv-label');
        if ($otherLabel.text().trim() !== '') return true;
        return $('.other-inventory .item-slot').length > 0;
    }

    // Fonction pour trouver le premier slot disponible
    function findFirstAvailableSlot($container) {
        var slot = null;
        $container.find('.item-slot').each(function(index) {
            if (slot !== null) return;
            var $s = $(this);

            // Verifier si le slot a une image (donc un item)
            var $img = $s.find('.item-slot-img img');
            if (!$img.length || !$img.attr('src')) {
                // Slot vide - utiliser data-slot
                slot = parseInt($s.attr('data-slot')) || (index + 1);
                return false;
            }
        });
        return slot;
    }

    // Fonction pour obtenir les donnees d'un item depuis un slot
    function getItemData($slot) {
        // Verifier d'abord via jQuery .data()
        var jqueryData = $slot.data('item');
        if (jqueryData && typeof jqueryData === 'object' && Object.keys(jqueryData).length > 0) {
            log('Item trouve via jQuery .data()');
            return jqueryData;
        }

        // Verifier via l'attribut data-item
        var attrData = $slot.attr('data-item');
        if (attrData && attrData !== '{}' && attrData !== 'null' && attrData !== '') {
            try {
                var parsed = JSON.parse(attrData);
                if (parsed && Object.keys(parsed).length > 0) {
                    log('Item trouve via attribut data-item');
                    return parsed;
                }
            } catch(e) {}
        }

        // Verifier si le slot a une image (indicateur qu'il y a un item)
        var $img = $slot.find('.item-slot-img img');
        if ($img.length && $img.attr('src')) {
            // Il y a un item! Extraire les infos depuis le HTML
            var imgSrc = $img.attr('src');
            var itemName = imgSrc.replace('images/', '').replace('.png', '');

            // Essayer de recuperer la quantite
            var amount = 1;
            var $amount = $slot.find('.item-slot-amount');
            if ($amount.length) {
                var amountText = $amount.text().trim();
                if (amountText && !isNaN(parseInt(amountText))) {
                    amount = parseInt(amountText);
                }
            }

            // Essayer de recuperer le label
            var label = itemName;
            var $label = $slot.find('.item-slot-label');
            if ($label.length && $label.text().trim()) {
                label = $label.text().trim();
            }

            log('Item reconstruit depuis HTML: ' + itemName + ' x' + amount);
            return {
                name: itemName,
                label: label,
                amount: amount
            };
        }

        return null;
    }

    function Post(action, data) {
        log('POST -> ' + action, JSON.stringify(data));
        return $.post('https://qs-inventory/' + action, JSON.stringify(data));
    }

    function performTransfer(from, to, fromSlot, toSlot, itemData, amount) {
        log('Transfer: ' + from + '[' + fromSlot + '] -> ' + to + '[' + toSlot + '] x' + amount);

        // Trouver les slots source et cible
        var $sourceSlot = $('.other-inventory .item-slot[data-slot="' + fromSlot + '"]');
        var $targetSlot = $('.player-inventory .item-slot[data-slot="' + toSlot + '"]');

        if (from === 'player') {
            $sourceSlot = $('.player-inventory .item-slot[data-slot="' + fromSlot + '"]');
            $targetSlot = $('.other-inventory .item-slot[data-slot="' + toSlot + '"]');
        }

        log('Source slot: ' + $sourceSlot.length + ', Target slot: ' + $targetSlot.length);

        // Methode: Simuler un vrai drag-and-drop jQuery UI
        if ($sourceSlot.length && $targetSlot.length) {
            log('Simulation drag-drop jQuery UI');
            try {
                // Obtenir les positions
                var sourceOffset = $sourceSlot.offset();
                var targetOffset = $targetSlot.offset();

                // Creer les evenements de souris
                var startX = sourceOffset.left + $sourceSlot.width() / 2;
                var startY = sourceOffset.top + $sourceSlot.height() / 2;
                var endX = targetOffset.left + $targetSlot.width() / 2;
                var endY = targetOffset.top + $targetSlot.height() / 2;

                // Simuler mousedown sur source
                var mousedownEvent = $.Event('mousedown', {
                    which: 1,
                    pageX: startX,
                    pageY: startY,
                    clientX: startX,
                    clientY: startY
                });
                $sourceSlot.trigger(mousedownEvent);

                // Simuler mousemove vers la cible
                setTimeout(function() {
                    var mousemoveEvent = $.Event('mousemove', {
                        which: 1,
                        pageX: endX,
                        pageY: endY,
                        clientX: endX,
                        clientY: endY
                    });
                    $(document).trigger(mousemoveEvent);

                    // Simuler mouseup sur cible
                    setTimeout(function() {
                        var mouseupEvent = $.Event('mouseup', {
                            which: 1,
                            pageX: endX,
                            pageY: endY,
                            clientX: endX,
                            clientY: endY
                        });
                        $targetSlot.trigger(mouseupEvent);
                        $(document).trigger(mouseupEvent);
                        log('Drag-drop simulation complete');
                    }, 50);
                }, 50);

            } catch (e) {
                log('Erreur drag-drop: ' + e.message);
            }
        }
    }

    // Handler pour player -> other
    function onPlayerRightClick(event) {
        log('Clic droit PLAYER');
        if (!isOtherInventoryOpen()) {
            log('Other inventory pas ouvert');
            return;
        }
        event.preventDefault();
        event.stopPropagation();

        var $slot = $(event.currentTarget);
        var itemData = getItemData($slot);

        if (!itemData) {
            log('Slot vide');
            return;
        }

        log('Item: ' + itemData.name + ' x' + itemData.amount);

        // Utiliser data-slot au lieu de data-slotid
        var fromSlot = parseInt($slot.attr('data-slot'));
        if (!fromSlot && fromSlot !== 0) {
            fromSlot = parseInt($slot.attr('data-slotid')) || $slot.index() + 1;
        }

        var toSlot = findFirstAvailableSlot($('.other-inventory'));
        if (!toSlot) {
            log('Pas de slot dispo dans other');
            return;
        }

        var amount = itemData.amount || 1;

        // Verifier le champ amount
        var $amountInput = $('#item-amount');
        if ($amountInput.length && $amountInput.val() && parseInt($amountInput.val()) > 0) {
            var inputAmount = parseInt($amountInput.val());
            if (inputAmount > 0 && inputAmount <= amount) {
                amount = inputAmount;
            }
        }

        // Obtenir le nom de l'inventaire cible
        var otherInvName = getOtherInventoryName();
        performTransfer('player', otherInvName, fromSlot, toSlot, itemData, amount);
    }

    // Handler pour other -> player
    function onOtherRightClick(event) {
        log('Clic droit OTHER');

        // Debug: afficher les variables globales disponibles
        log('DEBUG - otherLabel: ' + (typeof otherLabel !== 'undefined' ? otherLabel : 'undefined'));
        log('DEBUG - InventoryOption: ' + (typeof InventoryOption !== 'undefined' ? InventoryOption : 'undefined'));
        log('DEBUG - data-inventory: ' + $('.other-inventory').attr('data-inventory'));
        log('DEBUG - #other-inv-label: ' + $('#other-inv-label').text().trim());

        event.preventDefault();
        event.stopPropagation();

        var $slot = $(event.currentTarget);
        var itemData = getItemData($slot);

        if (!itemData) {
            log('Slot vide');
            return;
        }

        log('Item: ' + itemData.name + ' x' + itemData.amount);

        // Utiliser data-slot au lieu de data-slotid
        var fromSlot = parseInt($slot.attr('data-slot'));
        if (!fromSlot && fromSlot !== 0) {
            fromSlot = parseInt($slot.attr('data-slotid')) || $slot.index() + 1;
        }

        var toSlot = findFirstAvailableSlot($('.player-inventory'));
        if (!toSlot) {
            log('Pas de slot dispo dans player');
            return;
        }

        var amount = itemData.amount || 1;

        // Verifier le champ amount
        var $amountInput = $('#item-amount');
        if ($amountInput.length && $amountInput.val() && parseInt($amountInput.val()) > 0) {
            var inputAmount = parseInt($amountInput.val());
            if (inputAmount > 0 && inputAmount <= amount) {
                amount = inputAmount;
            }
        }

        // Obtenir le nom de l'inventaire source
        var otherInvName = getOtherInventoryName();
        performTransfer(otherInvName, 'player', fromSlot, toSlot, itemData, amount);
    }

    // Init
    $(document).ready(function() {
        log('Installation des handlers...');
        $(document).on('contextmenu', '.player-inventory .item-slot', onPlayerRightClick);
        $(document).on('contextmenu', '.other-inventory .item-slot', onOtherRightClick);
        log('Handlers installes OK');
    });

})();
