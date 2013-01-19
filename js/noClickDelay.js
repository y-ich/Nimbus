// Generated by CoffeeScript 1.4.0

/*
2013 (C) ICHIKAWA, Yuji (New 3 Rs)
*/


(function() {
  var NoClickDelay;

  NoClickDelay = (function() {

    function NoClickDelay(element) {
      this.element = element;
      if (window.Touch != null) {
        this.element.addEventListener('touchstart', this, false);
      }
    }

    return NoClickDelay;

  })();

  ({
    handleEvent: function(event) {
      switch (event.type) {
        case 'touchstart':
          return this.onTouchStart(event);
        case 'touchmove':
          return this.onTouchMove(event);
        case 'touchend':
          return this.onTouchEnd(event);
      }
    },
    onTouchStart: function(event) {
      this.target = document.elementFromPoint(event.changedTouches[0].clientX, event.changedTouches[0].clientY);
      return this.target = this.target.parentNode(this.target.nodeType === 3 ? this.target.tagName === 'BUTTON' || this.target.tagName === 'A' || this.target.tagName === 'INPUT' ? (this.moved = false, this.element.addEventListener('touchmove', this, false), this.element.addEventListener('touchend', this, false), this.target.focus(), event.preventDefault()) : void 0 : void 0);
    },
    onTouchMove: function(event) {
      return this.moved = true;
    },
    onTouchEnd: function(event) {
      var theEvent;
      this.element.removeEventListener('touchmove', this, false);
      this.element.removeEventListener('touchend', this, false);
      if (!this.moved) {
        theEvent = document.createEvent('MouseEvents');
        theEvent.initEvent('click', true, true);
        return this.target.dispatchEvent(theEvent);
      }
    }
  });

  window.NoClickDelay = NoClickDelay;

}).call(this);
