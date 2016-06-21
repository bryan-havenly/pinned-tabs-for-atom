PinnedTabsState = require './pinned-tabs-state'
{CompositeDisposable} = require 'atom'

module.exports = PinnedTabs =
    config:
        animated:
            title: 'Disable animations'
            description: 'Tick this to disable all animation related to Pinned Tabs'
            default: false
            type: 'boolean'
        closeUnpinned:
            title: 'Disable the \'Close Unpinned Tabs\' option'
            description: 'Tick this to hide the \'Close Unpinned Tabs\' from the context menu'
            default: true
            type: 'boolean'
        modified:
            title: 'Disable the modified icon on pinned tabs'
            description: 'Tick this to disable the modified icon when hovering over pinned tabs'
            default: false
            type: 'boolean'

    PinnedTabsState: undefined


	# Core
    activate: (state) ->
        @observers()
        @prepareConfig()
        @setCommands()

        # Recover the serialized session or start a new serializable state.
        @PinnedTabsState =
            if state.deserializer == 'PinnedTabsState'
                atom.deserializers.deserialize state
            else
                new PinnedTabsState { }

        if @PinnedTabsState._reset_ == undefined
            @PinnedTabsState._reset_ = true
            @PinnedTabsState.data = {}

        # Restore the serialized session.
        # This timeout ensures that the DOM elements can be edited.
        setTimeout (=>
            tabbars = document.querySelectorAll '.tab-bar'
            state = this.PinnedTabsState.data

            for index of state
                if state[index] < 0 || isNaN(state[index]) || index > tabbars.length
                    delete state[index]
                    continue

                tabbar = tabbars[index]
                for i in [0...state[index]]
                    if i < tabbar.children.length
                        tabbar.children[i].classList.add 'pinned'
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
        atom.workspace.onDidAddPaneItem () =>
            setTimeout (=>
                e = document.querySelector('.tab-bar .tab.active')
                return unless tab = this.getTabInformation e

                if tab.pinIndex > tab.tabIndex
                    tab.pane.moveItem(tab.item, tab.pinIndex)
            ), 1

        # Reduce the amount of pinned tabs when one is destoryed
        atom.workspace.onWillDestroyPaneItem (event) =>
            tabIndex = Array.prototype.indexOf.call(event.pane.getItems(), event.item)
            textEditor = event.item.element

            # If a tab has not been opened yet, it is not yet in the DOM,
            # so get the active element of the pane (which is opened by definition)
            if textEditor.parentNode == null
                textEditor = event.pane.activeItem.element

            atomPane = textEditor.parentNode.parentNode
            tabbarNode = atomPane.querySelector '.tab-bar'
            tabbars = document.querySelectorAll '.tab-bar'
            tabbarIndex = Array.prototype.indexOf.call(tabbars, tabbarNode)

            if tabbarNode.children[tabIndex].classList.contains('pinned')
                @PinnedTabsState.data[tabbarIndex] -= 1

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
                #activePane.itemAtIndex i
                activePane.destroyItem activePane.itemAtIndex(i)

    pinActive: ->
        @pin document.querySelector('.tab-bar .tab.active')

    pinSelected: ->
        @pin atom.contextMenu.activeElement

    pin: (e) ->
        return unless info = @getTabInformation e

        # Initialize the state key for this pane if needed
        if @PinnedTabsState.data[info.tabbarIndex] == undefined || isNaN(@PinnedTabsState.data[info.tabbarIndex])
            @PinnedTabsState.data[info.tabbarIndex] = 0

        if info.tabIsPinned
            @PinnedTabsState.data[info.tabbarIndex] -= 1
            info.pane.moveItem(info.item, info.unpinIndex)
        else
            @PinnedTabsState.data[info.tabbarIndex] += 1
            info.pane.moveItem(info.item, info.pinIndex)

        setTimeout (-> e.classList.toggle 'pinned' ), 1

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

        return {
            tabIndex: tabIndex,
            tabbarIndex: tabbarIndex,

            pinIndex: pinIndex,
            unpinIndex: pinIndex - 1,

            item: item,
            pane: pane,

            tabIsPinned: e.classList.contains 'pinned'
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
        body.classList.toggle 'pinned-tabs-animated', !enable

    closeUnpinned: (enable) ->
        body = document.querySelector 'body'
        body.classList.toggle 'close-unpinned', !enable

    modified: (enable) ->
        body = document.querySelector 'body'
        body.classList.toggle 'pinned-tabs-modified', !enable
