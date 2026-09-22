export const FlashAutoDismiss = {
  mounted() {
    this.init();
  },

  updated() {
    this.init();
  },

  destroyed() {
    this.clear();
  },

  init() {
    this.clear();
    const duration = parseInt(this.el.dataset.autoDismiss || "5000", 10);
    if (!duration || duration <= 0) return;

    this.remaining = duration;
    this.startTime = Date.now();

    const startTimer = (timeMs) => {
      this.timer = setTimeout(() => {
        this.dismiss();
      }, timeMs);
    };

    startTimer(this.remaining);

    // Mettre en pause la disparition lorsque l'utilisateur survole l'alerte
    this.onEnter = () => {
      if (this.timer) {
        clearTimeout(this.timer);
        this.timer = null;
        const elapsed = Date.now() - this.startTime;
        this.remaining = Math.max(0, this.remaining - elapsed);
      }
    };

    // Reprendre le compte à rebours lorsque la souris quitte l'alerte
    this.onLeave = () => {
      if (!this.timer && this.remaining > 0) {
        this.startTime = Date.now();
        startTimer(this.remaining);
      }
    };

    this.el.addEventListener("mouseenter", this.onEnter);
    this.el.addEventListener("mouseleave", this.onLeave);
  },

  clear() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    if (this.onEnter) {
      this.el.removeEventListener("mouseenter", this.onEnter);
      this.onEnter = null;
    }
    if (this.onLeave) {
      this.el.removeEventListener("mouseleave", this.onLeave);
      this.onLeave = null;
    }
  },

  dismiss() {
    this.clear();
    // Déclenche l'événement click pour activer phx-click (lv:clear-flash + hide transition)
    this.el.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
  }
};
