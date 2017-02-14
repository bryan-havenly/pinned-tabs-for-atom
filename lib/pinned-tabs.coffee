PinnedTabsState = require './pinned-tabs-state'
{Emitter, CompositeDisposable} = require 'atom'

module.exports = PinnedTabs =
    config:
        animated:
            title: 'Enable animations'
            description: 'Tick this to enable all animation related to pinned tabs'
            default: true
            type: 'boolean'
        closeUnpinned:
            title: 'Enable the \'Close Unpinned Tabs\' option'
            description: 'Tick this to show the \'Close Unpinned Tabs\' from the context menu'
            default: false
            type: 'boolean'
        modified:
            title: 'Enable the modified icon on pinned tabs'
            description: 'Tick this to enable the modified icon when hovering over pinned tabs'
            default: true
            type: 'boolean'
        preventCloseAll:
            title: 'Prevent \'Close all tabs\' from closing pinned tabs'
            description: 'Prevent the native \'Close all tabs\' from closing pinned tabs'
            default: true
            type: 'boolean'

    PinnedTabsState: undefined
    fCloseAllTabs: false


    activate: (state) ->
        @observers()
        @prepareConfig()
        @setCommands()

        # Toggle flag for close-all-tabs command to prevent closing pinned tabs.
        atom.commands.onWillDispatch (e) =>
            @fCloseAllTabs = true if e.type == 'tabs:close-all-tabs'
        atom.commands.onDidDispatch (e) =>
            @fCloseAllTabs = false if e.type == 'tabs:close-all-tabs'

        # Recover the serialized session or start a new serializable state.
        @PinnedTabsState =
            if state.deserializer == 'PinnedTabsState'
                atom.deserializers.deserialize state
            else
                new PinnedTabsState { }

        if @PinnedTabsState.__reset == undefined
            @PinnedTabsState.__reset = true
            @PinnedTabsState.data = []

        # Restore the serialized session.
        # This timeout ensures that the DOM elements can be edited.
        setTimeout (=>
            tabbars = document.querySelectorAll '.tab-bar'
            state = @PinnedTabsState.data

            for tabbar in tabbars
                for i in [0...tabbar.children.length]
                    tab = tabbar.children[i]
                    info = @getTabInformation tab

                    if state.indexOf(info.itemId) >= 0
                        tab.classList.add 'pinned'
                    else if state.indexOf(info.itemURI) >= 0
                        tab.classList.add 'pinned'
        ), 1

    serialize: ->
        @PinnedTabsState.serialize()


    # Register commands for this package.
    setCommands: ->
        @subscriptions = new CompositeDisposable
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:pin': => @pinActive()
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:pin-selected': => @pinSelected()
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:close-unpinned': => @closeUnpinned()

    # Observer panes
    observers: ->
        # Move new tabs after pinned tabs
        atom.workspace.onDidAddPaneItem (e) =>
            setTimeout (=>
                tabs = e.pane.items
                pinnedCounter = 0
                for i in [0..(tabs.length - 1)]
                    if @PinnedTabsState.data.indexOf(tabs[i].id) >= 0
                        pinnedCounter += 1

                if e.index < pinnedCounter
                    e.pane.moveItem(e.item, pinnedCounter)
            ), 1

        # Reduce the amount of pinned tabs when one is destoryed
        atom.workspace.onWillDestroyPaneItem (e) =>
            index = @PinnedTabsState.data.indexOf e.item.id
            if index >= 0 # The tab to be closed is currently pinned.
                if @fCloseAllTabs && atom.config.get('pinned-tabs.preventCloseAll')
                    e.prevent()
                else
                    @PinnedTabsState.data.splice(index, 1)

    setCommands: ->
        @subscriptions = new CompositeDisposable
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:pin': => @pinActive()
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:pin-selected': => @pinSelected()
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:close-unpinned': => @closeUnpinnedTabs()


	# Pin tabs
    closeUnpinnedTabs: ->
        activePane = document.querySelector '.pane.active'
        tabbar = activePane.querySelector '.tab-bar'

        activePane = atom.workspace.getActivePane()
        tabs = tabbar.querySelectorAll '.tab'
        for i in [(tabs.length - 1)..0]
            if !tabs[i].classList.contains('pinned')
                activePane.destroyItem activePane.itemAtIndex(i)

    pinActive: ->
        @pin document.querySelector('.tab-bar .tab.active')

    pinSelected: ->
        @pin atom.contextMenu.activeElement

    pin: (e) ->
        return unless info = @getTabInformation e

        if info.isPinned
            index = @PinnedTabsState.data.indexOf info.itemId
            @PinnedTabsState.data.splice(index, 1) if index >= 0
            info.pane.moveItem(info.item, info.unpinIndex)
        else
            @PinnedTabsState.data.push info.itemId
            info.pane.moveItem(info.item, info.pinIndex)

        setTimeout (-> e.classList.toggle 'pinned'), 1

    getTabInformation: (e) ->
        return if e == null

        tabbarNode = e.parentNode
        paneNode = tabbarNode.parentNode
        axisNode = paneNode.parentNode

        pinIndex = tabbarNode.querySelectorAll('.pinned').length
        tabbars = document.querySelectorAll('.tab-bar')

        tabIndex = Array.prototype.indexOf.call(tabbarNode.children, e)
        tabbarIndex = Array.prototype.indexOf.call(tabbars, tabbarNode)
        paneIndex = Array.prototype.indexOf.call(axisNode.children, paneNode)

        pane = atom.workspace.getPanes()[paneIndex / 2]
        item = pane.itemAtIndex(tabIndex)

        itemId = item.id if item
        itemURI = item.getURI() if item && item.getURI

        return {
            tabIndex: tabIndex,
            tabbarIndex: tabbarIndex,

            pinIndex: pinIndex,
            unpinIndex: pinIndex - 1,

            item: item,
            itemId: itemId || itemURI,
            pane: pane,

            isPinned: e.classList.contains 'pinned'
        }


    # Configuration
    prepareConfig: ->
        animated = 'pinned-tabs.animated'
        atom.config.onDidChange animated, ({newValue, oldValue}) =>
            @animated newValue
        @animated atom.config.get(animated)

        closeUnpinned = 'pinned-tabs.closeUnpinned'
        atom.config.onDidChange closeUnpinned, ({newValue, oldValue}) =>
            @closeUnpinned newValue
        @closeUnpinned atom.config.get(closeUnpinned)

        modified = 'pinned-tabs.modified'
        atom.config.onDidChange modified, ({newValue, oldValue}) =>
            @modified newValue
        @modified atom.config.get(modified)

    animated: (enable) ->
        body = document.querySelector 'body'
        body.classList.toggle 'pinned-tabs-animated', enable

    closeUnpinned: (enable) ->
        body = document.querySelector 'body'
        body.classList.toggle 'close-unpinned', enable

    modified: (enable) ->
        body = document.querySelector 'body'
        body.classList.toggle 'pinned-tabs-modified', enable
