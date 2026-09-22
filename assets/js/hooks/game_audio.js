/**
 * GameAudio Hook - Quizir
 * Gestion des effets sonores (clic réponse, son de révélation)
 * et de 3 musiques de fond aléatoires procédurales via Web Audio API.
 */

export const GameAudio = {
  mounted() {
    this.initAudio();
    this.initListeners();
    this.renderUIState();
  },

  updated() {
    const trackAttr = parseInt(this.el.dataset.musicTrack || "1", 10);
    if (trackAttr && trackAttr !== this.currentTrack && !this.userSelectedTrack) {
      this.currentTrack = trackAttr;
      this.renderUIState();
      if (!this.musicMuted && this.isPlayingMusic) {
        this.restartMusic();
      }
    }
  },

  destroyed() {
    this.stopMusic();
    if (this.schedulerTimer) {
      clearInterval(this.schedulerTimer);
      this.schedulerTimer = null;
    }
    if (this.audioCtx) {
      try {
        this.audioCtx.close();
      } catch (_) {}
      this.audioCtx = null;
    }
  },

  initAudio() {
    this.sfxMuted = localStorage.getItem("quizir_sfx_muted") === "true";
    this.musicMuted = localStorage.getItem("quizir_music_muted") === "true";

    // Piste aléatoire fournie par LiveView ou 1 par défaut
    const initialTrack = parseInt(this.el.dataset.musicTrack || "1", 10);
    const savedTrack = localStorage.getItem("quizir_music_track");
    this.currentTrack = savedTrack ? parseInt(savedTrack, 10) : (initialTrack >= 1 && initialTrack <= 3 ? initialTrack : 1);
    this.userSelectedTrack = !!savedTrack;

    this.isPlayingMusic = false;
    this.currentStep = 0;
    this.nextNoteTime = 0;
    this.schedulerTimer = null;

    this.trackNames = {
      1: "Arcade Beat",
      2: "Quiz Lounge",
      3: "Tension Arena"
    };

    // Auto-resume sur première interaction
    const unlockAudio = () => {
      this.ensureContext();
      if (this.audioCtx && this.audioCtx.state === "suspended") {
        this.audioCtx.resume().then(() => {
          if (!this.musicMuted && !this.isPlayingMusic) {
            this.startMusic();
          }
        });
      } else if (!this.musicMuted && !this.isPlayingMusic) {
        this.startMusic();
      }
      document.removeEventListener("pointerdown", unlockAudio);
      document.removeEventListener("keydown", unlockAudio);
    };

    document.addEventListener("pointerdown", unlockAudio, { once: true });
    document.addEventListener("keydown", unlockAudio, { once: true });
  },

  ensureContext() {
    if (!this.audioCtx) {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) return null;

      this.audioCtx = new AudioContextClass();

      // Bus SFX
      this.sfxGain = this.audioCtx.createGain();
      this.sfxGain.gain.setValueAtTime(this.sfxMuted ? 0 : 0.45, this.audioCtx.currentTime);
      this.sfxGain.connect(this.audioCtx.destination);

      // Bus Musique
      this.musicGain = this.audioCtx.createGain();
      this.musicGain.gain.setValueAtTime(this.musicMuted ? 0 : 0.12, this.audioCtx.currentTime);
      this.musicGain.connect(this.audioCtx.destination);
    }
    return this.audioCtx;
  },

  initListeners() {
    // 1. Événements reçus depuis le serveur Phoenix LiveView
    this.handleEvent("play_sound", (payload) => {
      this.ensureContext();
      if (this.audioCtx && this.audioCtx.state === "suspended") {
        this.audioCtx.resume();
      }

      switch (payload.type) {
        case "click":
          this.playClickSound();
          break;
        case "reveal":
          this.playRevealSound(payload.is_correct);
          break;
        case "game_start":
          this.playGameStartSound();
          if (!this.musicMuted && !this.isPlayingMusic) {
            this.startMusic();
          }
          break;
        case "game_finished":
          this.playVictorySound();
          break;
      }
    });

    // 2. Clic direct sur les boutons de réponse pour un retour sonore instantané à 0ms
    document.addEventListener("click", (e) => {
      const target = e.target.closest("[phx-click='submit_answer'], [id^='answer-option-btn-']");
      if (target && !target.disabled) {
        this.playClickSound();
      }
    });

    // 3. Boutons de contrôle audio dans l'interface
    const sfxBtn = document.getElementById("audio-sfx-toggle");
    if (sfxBtn) {
      sfxBtn.addEventListener("click", () => this.toggleSfx());
    }

    const musicBtn = document.getElementById("audio-music-toggle");
    if (musicBtn) {
      musicBtn.addEventListener("click", () => this.toggleMusic());
    }

    const trackBtn = document.getElementById("audio-track-toggle");
    if (trackBtn) {
      trackBtn.addEventListener("click", () => this.cycleTrack());
    }
  },

  // ==========================================
  // EFFETS SONORES (SFX)
  // ==========================================

  playClickSound() {
    if (this.sfxMuted) return;
    const ctx = this.ensureContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = "triangle";
      // Chute de fréquence ultra-rapide type switch mécanique / bulle
      osc.frequency.setValueAtTime(880, now);
      osc.frequency.exponentialRampToValueAtTime(180, now + 0.05);

      gain.gain.setValueAtTime(0.6, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.055);

      osc.connect(gain);
      gain.connect(this.sfxGain);

      osc.start(now);
      osc.stop(now + 0.06);
    } catch (_) {}
  },

  playRevealSound(isCorrect) {
    if (this.sfxMuted) return;
    const ctx = this.ensureContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;

      if (isCorrect === true) {
        // Son triomphal : Fanfare 4 cloches montantes (C5, E5, G5, C6)
        const notes = [523.25, 659.25, 783.99, 1046.50];
        notes.forEach((freq, idx) => {
          const noteStart = now + idx * 0.09;
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();

          osc.type = "sine";
          osc.frequency.setValueAtTime(freq, noteStart);

          // Cloche brillante
          gain.gain.setValueAtTime(0.4, noteStart);
          gain.gain.exponentialRampToValueAtTime(0.001, noteStart + 0.6);

          osc.connect(gain);
          gain.connect(this.sfxGain);

          osc.start(noteStart);
          osc.stop(noteStart + 0.65);
        });
      } else if (isCorrect === false) {
        // Son échec : Buzzer comique descendant (Eb4 -> C4 -> A3)
        const osc = ctx.createOscillator();
        const filter = ctx.createBiquadFilter();
        const gain = ctx.createGain();

        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(311.13, now);
        osc.frequency.exponentialRampToValueAtTime(164.81, now + 0.45);

        filter.type = "lowpass";
        filter.frequency.setValueAtTime(900, now);
        filter.frequency.exponentialRampToValueAtTime(250, now + 0.45);

        gain.gain.setValueAtTime(0.35, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);

        osc.connect(filter);
        filter.connect(gain);
        gain.connect(this.sfxGain);

        osc.start(now);
        osc.stop(now + 0.52);
      } else {
        // Révélation neutre (Hôte / timeout / spectateur) : Accord brillant de suspense
        const chord = [440, 554.37, 659.25, 880];
        chord.forEach((freq, idx) => {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();

          osc.type = "triangle";
          osc.frequency.setValueAtTime(freq, now + idx * 0.04);

          gain.gain.setValueAtTime(0.3, now + idx * 0.04);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.7);

          osc.connect(gain);
          gain.connect(this.sfxGain);

          osc.start(now + idx * 0.04);
          osc.stop(now + 0.75);
        });
      }
    } catch (_) {}
  },

  playGameStartSound() {
    if (this.sfxMuted) return;
    const ctx = this.ensureContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      const notes = [392.00, 523.25, 659.25, 783.99]; // G4, C5, E5, G5
      notes.forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = "triangle";
        osc.frequency.setValueAtTime(freq, now + idx * 0.08);

        gain.gain.setValueAtTime(0.35, now + idx * 0.08);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 0.4);

        osc.connect(gain);
        gain.connect(this.sfxGain);

        osc.start(now + idx * 0.08);
        osc.stop(now + idx * 0.08 + 0.45);
      });
    } catch (_) {}
  },

  playVictorySound() {
    if (this.sfxMuted) return;
    const ctx = this.ensureContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      // Fanfare de victoire : C5 - G5 - C6
      const fanfare = [
        { f: 523.25, t: 0.0, d: 0.2 },
        { f: 659.25, t: 0.2, d: 0.2 },
        { f: 783.99, t: 0.4, d: 0.2 },
        { f: 1046.5, t: 0.6, d: 0.8 }
      ];

      fanfare.forEach(({ f, t, d }) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = "sine";
        osc.frequency.setValueAtTime(f, now + t);

        gain.gain.setValueAtTime(0.4, now + t);
        gain.gain.exponentialRampToValueAtTime(0.001, now + t + d);

        osc.connect(gain);
        gain.connect(this.sfxGain);

        osc.start(now + t);
        osc.stop(now + t + d + 0.05);
      });
    } catch (_) {}
  },

  // ==========================================
  // MUSIQUE DE FOND (3 PISTES PROCÉDURALES)
  // ==========================================

  startMusic() {
    const ctx = this.ensureContext();
    if (!ctx) return;

    if (this.isPlayingMusic) return;
    this.isPlayingMusic = true;

    if (this.musicMuted) {
      this.musicGain.gain.setValueAtTime(0, ctx.currentTime);
    } else {
      this.musicGain.gain.setValueAtTime(0.12, ctx.currentTime);
    }

    this.currentStep = 0;
    this.nextNoteTime = ctx.currentTime + 0.05;

    if (this.schedulerTimer) clearInterval(this.schedulerTimer);
    this.schedulerTimer = setInterval(() => this.scheduleNotes(), 80);
    this.renderUIState();
  },

  stopMusic() {
    this.isPlayingMusic = false;
    if (this.schedulerTimer) {
      clearInterval(this.schedulerTimer);
      this.schedulerTimer = null;
    }
    this.renderUIState();
  },

  restartMusic() {
    this.stopMusic();
    this.startMusic();
  },

  scheduleNotes() {
    const ctx = this.ensureContext();
    if (!ctx || !this.isPlayingMusic) return;

    const trackConfig = this.getTrackConfig(this.currentTrack);
    const stepDuration = 60 / trackConfig.bpm / 4; // 16th note duration

    // Programmer à l'avance jusqu'à currentTime + 0.25s
    while (this.nextNoteTime < ctx.currentTime + 0.25) {
      this.playTrackStep(this.currentTrack, this.currentStep, this.nextNoteTime, stepDuration);
      this.nextNoteTime += stepDuration;
      this.currentStep = (this.currentStep + 1) % trackConfig.totalSteps;
    }
  },

  getTrackConfig(trackNum) {
    switch (trackNum) {
      case 2:
        return { bpm: 90, totalSteps: 32 }; // Quiz Lounge (Lo-Fi Chill)
      case 3:
        return { bpm: 112, totalSteps: 32 }; // Tension Arena (Game Show Suspense)
      case 1:
      default:
        return { bpm: 124, totalSteps: 32 }; // Arcade Beat (Retro 8-bit Upbeat)
    }
  },

  playTrackStep(trackNum, step, time, duration) {
    const ctx = this.audioCtx;
    if (!ctx) return;

    if (trackNum === 1) {
      // --- PISTE 1: Arcade Beat (BPM 124) ---
      // Ligne de basse retro 8-bit sur triangle
      const bassNotes = [
        130.81, 0, 130.81, 0,  155.56, 0, 155.56, 0,  // C3, Eb3
        174.61, 0, 174.61, 0,  196.00, 0, 233.08, 0,  // F3, G3, Bb3
        130.81, 0, 130.81, 0,  155.56, 0, 155.56, 0,  // C3, Eb3
        196.00, 0, 233.08, 0,  261.63, 0, 196.00, 0   // G3, Bb3, C4, G3
      ];

      const bassFreq = bassNotes[step % bassNotes.length];
      if (bassFreq > 0) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(bassFreq, time);

        gain.gain.setValueAtTime(0.25, time);
        gain.gain.exponentialRampToValueAtTime(0.001, time + duration * 1.6);

        osc.connect(gain);
        gain.connect(this.musicGain);
        osc.start(time);
        osc.stop(time + duration * 1.7);
      }

      // Arpège mélodique pentatonique léger
      const arpNotes = [
        523.25, 622.25, 783.99, 932.33, 1046.50, 932.33, 783.99, 622.25,
        523.25, 622.25, 783.99, 1046.50, 1244.51, 1046.50, 783.99, 622.25
      ];
      if (step % 2 === 0) {
        const arpFreq = arpNotes[(step / 2) % arpNotes.length];
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(arpFreq, time);

        gain.gain.setValueAtTime(0.08, time);
        gain.gain.exponentialRampToValueAtTime(0.001, time + duration * 1.2);

        osc.connect(gain);
        gain.connect(this.musicGain);
        osc.start(time);
        osc.stop(time + duration * 1.3);
      }

    } else if (trackNum === 2) {
      // --- PISTE 2: Quiz Lounge (Lo-Fi Chill, BPM 90) ---
      // Accords doux style piano électrique Rhodes (Dm7, G7, Cmaj7, Am7)
      const chords = [
        [293.66, 349.23, 440.00, 523.25], // Dm7 (steps 0-7)
        [196.00, 246.94, 293.66, 349.23], // G7  (steps 8-15)
        [261.63, 329.63, 392.00, 493.88], // Cmaj7 (steps 16-23)
        [220.00, 261.63, 329.63, 392.00]  // Am7 (steps 24-31)
      ];

      const chordIdx = Math.floor(step / 8);
      // Nappe d'accord sur le premier temps et contretemps
      if (step % 4 === 0) {
        const currentChord = chords[chordIdx];
        currentChord.forEach((f) => {
          const osc = ctx.createOscillator();
          const filter = ctx.createBiquadFilter();
          const gain = ctx.createGain();

          osc.type = "sine";
          osc.frequency.setValueAtTime(f, time);

          filter.type = "lowpass";
          filter.frequency.setValueAtTime(700, time);

          gain.gain.setValueAtTime(0.09, time);
          gain.gain.exponentialRampToValueAtTime(0.001, time + duration * 3.8);

          osc.connect(filter);
          filter.connect(gain);
          gain.connect(this.musicGain);

          osc.start(time);
          osc.stop(time + duration * 3.9);
        });
      }

      // Sub-basse ronde
      const subBasses = [146.83, 98.00, 130.81, 110.00]; // D2, G1, C2, A1
      if (step % 8 === 0) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(subBasses[chordIdx], time);

        gain.gain.setValueAtTime(0.25, time);
        gain.gain.exponentialRampToValueAtTime(0.001, time + duration * 6);

        osc.connect(gain);
        gain.connect(this.musicGain);

        osc.start(time);
        osc.stop(time + duration * 6.2);
      }

    } else if (trackNum === 3) {
      // --- PISTE 3: Tension Arena (Game Show Suspense, BPM 112) ---
      // Rythme d'horloge staccato / pulsation de tension
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = "triangle";
      // Alternance basse de pulsation
      const tensionFreq = (step % 4 === 0) ? 164.81 : (step % 2 === 0 ? 220.00 : 329.63);
      osc.frequency.setValueAtTime(tensionFreq, time);

      gain.gain.setValueAtTime(0.18, time);
      gain.gain.exponentialRampToValueAtTime(0.001, time + duration * 0.7);

      osc.connect(gain);
      gain.connect(this.musicGain);

      osc.start(time);
      osc.stop(time + duration * 0.75);

      // Coups de tension dramatiques (chords)
      if (step === 0 || step === 16) {
        const dramaticNotes = [220, 261.63, 311.13, 440];
        dramaticNotes.forEach((f) => {
          const dOsc = ctx.createOscillator();
          const dGain = ctx.createGain();
          dOsc.type = "sawtooth";
          dOsc.frequency.setValueAtTime(f, time);

          dGain.gain.setValueAtTime(0.07, time);
          dGain.gain.exponentialRampToValueAtTime(0.001, time + duration * 3.5);

          dOsc.connect(dGain);
          dGain.connect(this.musicGain);

          dOsc.start(time);
          dOsc.stop(time + duration * 3.6);
        });
      }
    }
  },

  // ==========================================
  // COMMANDES UTILISATEUR & INTERFACE
  // ==========================================

  toggleSfx() {
    this.sfxMuted = !this.sfxMuted;
    localStorage.setItem("quizir_sfx_muted", this.sfxMuted.toString());
    if (this.sfxGain && this.audioCtx) {
      this.sfxGain.gain.setValueAtTime(this.sfxMuted ? 0 : 0.45, this.audioCtx.currentTime);
    }
    this.renderUIState();
    if (!this.sfxMuted) {
      this.playClickSound();
    }
  },

  toggleMusic() {
    this.ensureContext();
    if (this.audioCtx && this.audioCtx.state === "suspended") {
      this.audioCtx.resume();
    }

    this.musicMuted = !this.musicMuted;
    localStorage.setItem("quizir_music_muted", this.musicMuted.toString());

    if (this.musicGain && this.audioCtx) {
      this.musicGain.gain.setValueAtTime(this.musicMuted ? 0 : 0.12, this.audioCtx.currentTime);
    }

    if (!this.musicMuted && !this.isPlayingMusic) {
      this.startMusic();
    }

    this.renderUIState();
  },

  cycleTrack() {
    this.ensureContext();
    if (this.audioCtx && this.audioCtx.state === "suspended") {
      this.audioCtx.resume();
    }

    // Basculer entre 1, 2 et 3
    this.currentTrack = (this.currentTrack % 3) + 1;
    this.userSelectedTrack = true;
    localStorage.setItem("quizir_music_track", this.currentTrack.toString());

    if (!this.musicMuted) {
      this.restartMusic();
    }
    this.renderUIState();
  },

  renderUIState() {
    const sfxBtn = document.getElementById("audio-sfx-toggle");
    if (sfxBtn) {
      sfxBtn.setAttribute("data-muted", this.sfxMuted ? "true" : "false");
      const icon = sfxBtn.querySelector(".sfx-icon");
      const text = sfxBtn.querySelector(".sfx-text");
      if (icon) {
        icon.className = this.sfxMuted ? "hero-speaker-x-mark size-3.5 text-zinc-400" : "hero-speaker-wave size-3.5 text-emerald-500";
      }
      if (text) {
        text.textContent = this.sfxMuted ? "SFX: Off" : "SFX: On";
      }
    }

    const musicBtn = document.getElementById("audio-music-toggle");
    if (musicBtn) {
      musicBtn.setAttribute("data-muted", this.musicMuted ? "true" : "false");
      const icon = musicBtn.querySelector(".music-icon");
      const text = musicBtn.querySelector(".music-text");
      if (icon) {
        icon.className = this.musicMuted ? "hero-speaker-x-mark size-3.5 text-zinc-400" : "hero-musical-note size-3.5 text-primary";
      }
      if (text) {
        text.textContent = this.musicMuted ? "Musique: Off" : `Piste ${this.currentTrack}`;
      }
    }

    const trackLabel = document.getElementById("audio-track-label");
    if (trackLabel) {
      trackLabel.textContent = this.trackNames[this.currentTrack] || `Piste ${this.currentTrack}`;
    }
  }
};
