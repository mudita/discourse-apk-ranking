import { i18n } from "discourse-i18n";

// Placeholder mark drawn after the design until the final InkApps SVG
// arrives: swap the <svg> below and every place the badge renders follows.
const ApkInkappsBadge = <template>
    <a
      href={{@url}}
      target="_blank"
      rel="noopener noreferrer"
      class="sideloaded-inkapps-badge"
      title={{i18n "sideloaded_apps.inkapps.badge_title"}}
      aria-label={{i18n "sideloaded_apps.inkapps.badge_title"}}
      ...attributes
    >
      <svg
        class="sideloaded-inkapps-badge__icon"
        viewBox="0 0 24 24"
        aria-hidden="true"
        focusable="false"
      >
        <circle cx="10" cy="7" r="2.2" fill="currentColor" />
        <path
          d="M16 4v4M14 6h4"
          stroke="currentColor"
          stroke-width="1.4"
          stroke-linecap="round"
        />
        <rect
          x="6"
          y="12"
          width="12"
          height="7.5"
          rx="2"
          fill="none"
          stroke="currentColor"
          stroke-width="1.6"
        />
      </svg>
      {{#if @showLabel}}
        <span class="sideloaded-inkapps-badge__text">{{i18n
            "sideloaded_apps.inkapps.label"
          }}</span>
      {{/if}}
    </a>
</template>;

export default ApkInkappsBadge;
