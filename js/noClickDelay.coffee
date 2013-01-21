###
2013 (C) ICHIKAWA, Yuji (New 3 Rs)
###
class NoClickDelay
    constructor: (@element) ->
        @element.addEventListener 'touchstart', this, false if `'ontouchstart' in window` or window.DocumentTouch and document instanceof DocumentTouch

	handleEvent: (event) ->
		switch event.type
		     when 'touchstart' then @onTouchStart event
		     when 'touchmove' then @onTouchMove event
		     when 'touchend' then @onTouchEnd event

	onTouchStart: (event) ->
		@target = document.elementFromPoint event.changedTouches[0].clientX, event.changedTouches[0].clientY
		@target = @target.parentNode if @target.nodeType == 3
        if @target.tagName is 'BUTTON' or @target.tagName is 'A' or @target.tagName is 'INPUT'
            @moved = false
            @element.addEventListener 'touchmove', this, false
            @element.addEventListener 'touchend', this, false
            @target.focus()
            event.preventDefault()

	onTouchMove: (event) -> @moved = true

	onTouchEnd: (event) ->
		@element.removeEventListener 'touchmove', this, false
		@element.removeEventListener 'touchend', this, false

		if not @moved
			theEvent = document.createEvent 'MouseEvents'
			theEvent.initEvent 'click', true, true
			@target.dispatchEvent theEvent

window.NoClickDelay = NoClickDelay
