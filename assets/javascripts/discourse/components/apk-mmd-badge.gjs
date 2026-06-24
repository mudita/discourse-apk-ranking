import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

// Badge marking a review as an app dedicated for Mudita Kompakt (MMD).
// The inline SVG below is a placeholder mark — swap this markup to update
// the icon everywhere the badge renders (review header, topic list,
// moderation queue preview). Pass @showLabel={{true}} to also render the
// "MMD" text next to the icon.
export default class ApkMmdBadge extends Component {
  get showLabel() {
    return this.args.showLabel ?? false;
  }

  <template>
    <span
      class="sideloaded-mmd-badge"
      title={{i18n "sideloaded_apps.mmd_badge_title"}}
      role="img"
      aria-label={{i18n "sideloaded_apps.mmd_badge_title"}}
      ...attributes
    >
      <svg
        class="sideloaded-mmd-badge__icon"
        viewBox="0 0 24 24"
        width="16"
        height="16"
        aria-hidden="true"
        focusable="false"
      >
        <rect x="6" y="2.5" width="12" height="19" rx="3" fill="currentColor" />
        <rect
          x="8"
          y="5"
          width="8"
          height="12"
          rx="1"
          fill="var(--secondary, #fff)"
        />
        <circle cx="12" cy="19" r="1" fill="var(--secondary, #fff)" />
      </svg>
      {{#if this.showLabel}}
        <span class="sideloaded-mmd-badge__text">{{i18n
            "sideloaded_apps.mmd_badge"
          }}</span>
      {{/if}}
    </span>
  </template>
}
