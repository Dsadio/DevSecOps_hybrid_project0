/* ============================================================
   script.js — Site DevSecOps L3
   JavaScript vanilla, aucune dépendance externe.

   Fonctionnalités :
   1. Navbar : fond opaque au défilement + menu mobile
   2. Terminal du hero : simulation de sortie de pipeline
   3. Apparition des sections au défilement (IntersectionObserver)
   4. Pipeline : illumination en cascade des étapes
   5. Compteurs animés (section architecture)
   6. Année automatique dans le footer
   ============================================================ */

"use strict";

/* L'utilisateur préfère-t-il un mouvement réduit ? (accessibilité) */
const REDUCED_MOTION = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/* ------------------------------------------------------------
   1. Navbar : état "scrolled" + menu hamburger mobile
   ------------------------------------------------------------ */
const navbar    = document.getElementById("navbar");
const navToggle = document.getElementById("navToggle");
const navLinks  = document.getElementById("navLinks");

// Fond opaque dès que la page est défilée
function updateNavbar() {
    navbar.classList.toggle("scrolled", window.scrollY > 10);
}
window.addEventListener("scroll", updateNavbar, { passive: true });
updateNavbar();

// Ouverture / fermeture du menu mobile
navToggle.addEventListener("click", () => {
    const open = navLinks.classList.toggle("open");
    navToggle.classList.toggle("open", open);
    navToggle.setAttribute("aria-expanded", String(open));
});

// Fermer le menu après un clic sur un lien (navigation par ancres)
navLinks.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
        navLinks.classList.remove("open");
        navToggle.classList.remove("open");
        navToggle.setAttribute("aria-expanded", "false");
    });
});

/* ------------------------------------------------------------
   2. Terminal du hero : sortie de pipeline "tapée" ligne à ligne
   ------------------------------------------------------------
   Chaque entrée : { text, cls } où cls est une classe CSS
   de couleur (t-ok, t-info, t-warn, t-dim) ou null.        */
const TERMINAL_LINES = [
    { text: "$ git push origin main",                          cls: null     },
    { text: "→ Webhook reçu — démarrage du pipeline #42",      cls: "t-dim"  },
    { text: "",                                                cls: null     },
    { text: "[1/5] Pré-commit ........... OK",                 cls: "t-ok"   },
    { text: "[2/5] tfsec (Terraform) .... 0 vulnérabilité",    cls: "t-ok"   },
    { text: "[3/5] ansible-lint ......... conforme",           cls: "t-ok"   },
    { text: "[4/5] terraform apply ...... 6 ressources créées", cls: "t-info" },
    { text: "[5/5] ansible-playbook ..... serveur durci",      cls: "t-info" },
    { text: "",                                                cls: null     },
    { text: "✔ Déploiement AWS + on-prem réussi",              cls: "t-ok"   },
    { text: "⚑ Sécurité validée avant mise en production",     cls: "t-warn" },
];

const terminalBody = document.getElementById("terminalBody");

/**
 * Affiche les lignes du terminal une par une avec un effet de frappe.
 * Si l'utilisateur préfère un mouvement réduit, tout est affiché d'un bloc.
 */
function runTerminal() {
    if (!terminalBody) return;

    // Version sans animation
    if (REDUCED_MOTION) {
        TERMINAL_LINES.forEach(({ text, cls }) => {
            const line = document.createElement("span");
            if (cls) line.className = cls;
            line.textContent = text + "\n";
            terminalBody.appendChild(line);
        });
        return;
    }

    // Curseur clignotant, déplacé à la fin au fur et à mesure
    const cursor = document.createElement("span");
    cursor.className = "t-cursor";
    terminalBody.appendChild(cursor);

    let lineIndex = 0;
    let charIndex = 0;
    let currentSpan = null;

    function typeNext() {
        if (lineIndex >= TERMINAL_LINES.length) return; // terminé, curseur reste

        const { text, cls } = TERMINAL_LINES[lineIndex];

        // Créer le <span> de la ligne au premier caractère
        if (charIndex === 0) {
            currentSpan = document.createElement("span");
            if (cls) currentSpan.className = cls;
            terminalBody.insertBefore(currentSpan, cursor);
        }

        if (charIndex < text.length) {
            currentSpan.textContent += text[charIndex++];
            setTimeout(typeNext, 14); // vitesse de frappe
        } else {
            currentSpan.textContent += "\n";
            lineIndex++;
            charIndex = 0;
            // Pause plus longue entre les lignes vides / étapes
            setTimeout(typeNext, text === "" ? 120 : 260);
        }
    }

    setTimeout(typeNext, 600); // petit délai après le chargement
}
runTerminal();

/* ------------------------------------------------------------
   3. Apparition au défilement
   ------------------------------------------------------------
   On ajoute la classe .reveal aux blocs concernés, puis
   IntersectionObserver ajoute .visible quand ils entrent
   dans le viewport (le CSS gère la transition).            */
const revealTargets = document.querySelectorAll(
    ".card, .sec-item, .stage, .arch-diagram, .arch-text, .section h2, .section-intro"
);

revealTargets.forEach((el) => el.classList.add("reveal"));

const revealObserver = new IntersectionObserver(
    (entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add("visible");
                revealObserver.unobserve(entry.target); // une seule fois
            }
        });
    },
    { threshold: 0.15 }
);

revealTargets.forEach((el) => revealObserver.observe(el));

/* ------------------------------------------------------------
   4. Pipeline : illumination en cascade
   ------------------------------------------------------------
   Quand la section pipeline devient visible, chaque étape
   s'"allume" à tour de rôle, simulant le flux CI/CD.       */
const pipelineFlow = document.getElementById("pipelineFlow");

if (pipelineFlow) {
    const stages = pipelineFlow.querySelectorAll(".stage");

    const pipelineObserver = new IntersectionObserver(
        (entries) => {
            entries.forEach((entry) => {
                if (!entry.isIntersecting) return;
                pipelineObserver.disconnect(); // une seule exécution

                stages.forEach((stage, i) => {
                    const delay = REDUCED_MOTION ? 0 : 350 * (i + 1);
                    setTimeout(() => stage.classList.add("lit"), delay);
                });
            });
        },
        { threshold: 0.3 }
    );

    pipelineObserver.observe(pipelineFlow);
}

/* ------------------------------------------------------------
   5. Compteurs animés (statistiques architecture)
   ------------------------------------------------------------
   Chaque .stat-num possède un attribut data-count ; on
   incrémente de 0 à la valeur cible quand il est visible.  */
const counters = document.querySelectorAll(".stat-num[data-count]");

function animateCounter(el) {
    const target = parseInt(el.dataset.count, 10);

    if (REDUCED_MOTION || target <= 0) {
        el.textContent = target;
        return;
    }

    const duration = 900; // ms
    const start = performance.now();

    function tick(now) {
        const progress = Math.min((now - start) / duration, 1);
        el.textContent = Math.round(progress * target);
        if (progress < 1) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
}

const counterObserver = new IntersectionObserver(
    (entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                animateCounter(entry.target);
                counterObserver.unobserve(entry.target);
            }
        });
    },
    { threshold: 0.6 }
);

counters.forEach((el) => counterObserver.observe(el));

/* ------------------------------------------------------------
   6. Année automatique dans le footer
   ------------------------------------------------------------ */
const footerYear = document.getElementById("footerYear");
if (footerYear) {
    footerYear.textContent = "© " + new Date().getFullYear() + " — Projet DevSecOps L3";
}