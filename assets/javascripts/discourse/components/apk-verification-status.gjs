import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class ApkVerificationStatus extends Component {
  get verification() {
    return this.args.verification;
  }

  get shouldRender() {
    return this.verification || this.args.alwaysShow;
  }

  get combinedStatus() {
    const v = this.verification;
    if (!v) {
      return "unknown";
    }
    if (
      v.consistency_status === "inconsistent" ||
      v.availability_status === "unavailable"
    ) {
      return "danger";
    }
    if (
      v.availability_status === "available" &&
      v.consistency_status === "consistent"
    ) {
      return "success";
    }
    if (
      v.availability_status === "available" &&
      v.consistency_status === "unknown"
    ) {
      return "accessible";
    }
    return "unknown";
  }

  get statusIcon() {
    switch (this.combinedStatus) {
      case "success":
        return "✓";
      case "accessible":
        return "✓";
      case "danger":
        return "✗";
      default:
        return "—";
    }
  }

  get isFile() {
    return this.verification?.link_type !== "webpage";
  }

  get statusLabel() {
    const prefix = this.isFile ? "file" : "link";
    switch (this.combinedStatus) {
      case "success":
        return i18n("sideloaded_apps.verification.consistent_short");
      case "accessible":
        return i18n("sideloaded_apps.verification.accessible_short");
      case "danger":
        if (this.verification?.consistency_status === "inconsistent") {
          return i18n("sideloaded_apps.verification.inconsistent_short");
        }
        return i18n(`sideloaded_apps.verification.${prefix}_unavailable`);
      default:
        return i18n("sideloaded_apps.verification.unknown_short");
    }
  }

  get tooltip() {
    const v = this.verification;
    if (!v) {
      return i18n("sideloaded_apps.verification.never_checked");
    }

    const prefix = this.isFile ? "file" : "link";
    const parts = [];
    if (v.availability_status === "available") {
      parts.push(i18n(`sideloaded_apps.verification.${prefix}_available`));
    } else if (v.availability_status === "unavailable") {
      parts.push(i18n(`sideloaded_apps.verification.${prefix}_unavailable`));
    } else if (v.availability_description) {
      parts.push(v.availability_description);
    }
    if (v.consistency_description) {
      parts.push(v.consistency_description);
    }
    return parts.join(" | ") || i18n("sideloaded_apps.verification.unknown");
  }

  get lastChecked() {
    if (!this.verification?.last_checked_at) {
      return i18n("sideloaded_apps.verification.never_checked");
    }
    const date = new Date(this.verification.last_checked_at);
    const formatted = date.toLocaleString(undefined, {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      timeZoneName: "short",
    });
    return `${i18n("sideloaded_apps.verification.last_checked")}: ${formatted}`;
  }

  <template>
    {{#if this.shouldRender}}
      <div class="sideloaded-verification-status">
        <span
          class="sideloaded-verification-badge --{{this.combinedStatus}}"
          title={{this.tooltip}}
          role="img"
          aria-label={{this.tooltip}}
        >
          <span class="sideloaded-verification-badge__icon">
            {{this.statusIcon}}
          </span>
          <span class="sideloaded-verification-badge__label">
            {{this.statusLabel}}
          </span>
        </span>
        {{#if this.verification}}
          <span
            class="sideloaded-verification-status__last-checked"
            title={{this.lastChecked}}
          >
            {{this.lastChecked}}
          </span>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
