PinnedTabsView = require './pinned-tabs-view'
{CompositeDisposable} = require 'atom'

module.exports = PinnedTabs =
    # Method that is ran when the package is started.
    activate: (state) ->
        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable.
        @subscriptions = new CompositeDisposable

        # Register commands to pin a tab.
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:pin': => @pinActive()
        @subscriptions.add atom.commands.add 'atom-workspace', 'pinned-tabs:pin-selected': => @pinSelected()

    # Method that is ran when the package is stopped.
    deactivate: ->
        @pinnedTabsView.destroy()

    # Method that is ran to serialize the package.
    serialize: ->
        pinnedTabsViewState: @pinnedTabsView.serialize()


    # Method to pin the active tab.
    pinActive: ->
        @pin document.querySelector('.tab.active')

    # Method to pin the selected (via contextmenu) tab.
    pinSelected: ->
        @pin atom.contextMenu.activeElement

    pin: (e) ->
        # Get an instance of the Pane class to be able
        # to move the tabs around.
        pane = atom.workspace.getActivePane()

        # Get the index of the tab that should be pinned,
        # and get the item of the tab, so it can be moved.
        selectedIndex = Array.prototype.indexOf.call e.parentNode.children, e
        item = pane.itemAtIndex selectedIndex

        # Get the new index for the item.
        newIndex = e.parentNode.querySelectorAll('.pinned').length
        if e.classList.contains 'pinned'
            # If the element has the element 'pinned', it
            # is currently being unpinned. So the new index
            # is one off when look at the amount of pinned
            # tabs, because it actually includes the tab
            # that is being unpinned.
            newIndex -= 1

        # Actually move the item to its new index.
        pane.moveItem item, newIndex

        # Finally, toggle the 'pinned' class on the tab after a
        # timout of 1 millisecond. This will ensure the animation
        # of pinning the tab will run.
        callback = -> e.classList.toggle 'pinned'
        setTimeout callback, 1
