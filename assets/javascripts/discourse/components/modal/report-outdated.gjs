import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import preventScrollOnFocus from "discourse/modifiers/prevent-scroll-on-focus";
import { i18n } from "discourse-i18n";

const MIN_MESSAGE_LENGTH = 20;

export default class ReportOutdatedModal extends Component {
  @tracked message = "";
  @tracked submitting = false;
  @tracked validationError = null;

  get topicId() {
    return this.args.model?.topic_id;
  }

  get disabled() {
    return (
      this.submitting ||
      !this.message.trim() ||
      this.message.trim().length < MIN_MESSAGE_LENGTH
    );
  }

  get minLengthLabel() {
    return i18n("sideloaded_apps.report_outdated_modal.min_length", {
      count: MIN_MESSAGE_LENGTH,
    });
  }

  get submitButtonLabel() {
    return this.submitting
      ? i18n("sideloaded_apps.report_outdated_sending")
      : i18n("sideloaded_apps.report_outdated_submit");
  }

  @action
  updateMessage(value) {
    this.message = value;
    this.validationError = null;
  }

  @action
  async submit(event) {
    event?.preventDefault();
    const trimmed = this.message.trim();
    if (trimmed.length < MIN_MESSAGE_LENGTH) {
      this.validationError = this.minLengthLabel;
      return;
    }

    this.submitting = true;
    this.validationError = null;

    try {
      await ajax("/sideloaded-apps/report-outdated", {
        type: "POST",
        data: { topic_id: this.topicId, message: trimmed },
      });
      this.args.model?.onSuccess?.();
      this.args.closeModal();
      const dialog =
        window.__container__?.lookup("service:dialog") ||
        window.Discourse?.__container__?.lookup("service:dialog");
      if (dialog) {
        dialog.alert(i18n("sideloaded_apps.report_outdated_success"));
      }
    } catch (e) {
      this.validationError =
        e.jqXHR?.responseJSON?.error ||
        e.message ||
        i18n("sideloaded_apps.errors.unauthorized");
    } finally {
      this.submitting = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "sideloaded_apps.report_outdated"}}
      @closeModal={{@closeModal}}
      class="report-outdated-modal"
    >
      <:body>
        <p class="report-outdated-modal__intro">
          {{i18n "sideloaded_apps.report_outdated_modal.intro"}}
        </p>
        <form {{on "submit" this.submit}}>
          <div class="report-outdated-modal__field">
            <label for="report-outdated-message">
              {{i18n "sideloaded_apps.report_outdated_modal.message_label"}}
            </label>
            <textarea
              id="report-outdated-message"
              {{preventScrollOnFocus}}
              value={{this.message}}
              placeholder={{i18n "sideloaded_apps.report_outdated_modal.message_placeholder"}}
              {{on "input" (withEventValue (fn this.updateMessage))}}
              rows="4"
              class="input-large"
            />
            <span class="report-outdated-modal__hint">
              {{this.minLengthLabel}}
            </span>
            {{#if this.validationError}}
              <p class="report-outdated-modal__error">{{this.validationError}}</p>
            {{/if}}
          </div>
        </form>
      </:body>
      <:footer>
        <DButton
          @translatedLabel={{this.submitButtonLabel}}
          @action={{this.submit}}
          @disabled={{this.disabled}}
          class="btn-primary"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
