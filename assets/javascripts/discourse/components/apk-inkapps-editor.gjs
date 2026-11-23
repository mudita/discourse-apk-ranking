import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ApkInkappsEditor extends Component {
  @tracked draft = this.args.url || "";
  @tracked error = null;
  @tracked saving = false;

  @action
  updateDraft(event) {
    this.draft = event.target.value;
    this.error = null;
  }

  @action
  save(event) {
    event?.preventDefault();
    return this.submit(this.draft);
  }

  @action
  remove() {
    return this.submit("");
  }

  async submit(url) {
    this.saving = true;
    this.error = null;
    try {
      const result = await ajax(
        `/sideloaded-apps/reviews/${this.args.topicId}/inkapps`,
        { type: "PUT", data: { url } }
      );
      this.draft = result.inkapps_url || "";
      this.args.onChange?.(result.inkapps_url || null);
    } catch (e) {
      this.error = extractError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <form class="sideloaded-inkapps-editor" {{on "submit" this.save}}>
      <label class="sideloaded-inkapps-editor__label" for="sl-inkapps-url">
        {{i18n "sideloaded_apps.inkapps.editor_label"}}
      </label>
      <div class="sideloaded-inkapps-editor__row">
        <input
          id="sl-inkapps-url"
          type="url"
          placeholder="https://inkapps.mudita.com/apps/…"
          value={{this.draft}}
          disabled={{this.saving}}
          {{on "input" this.updateDraft}}
        />
        <button
          type="submit"
          class="btn btn-primary btn-small sideloaded-inkapps-editor__save"
          disabled={{this.saving}}
        >{{i18n "sideloaded_apps.inkapps.save"}}</button>
        {{#if @url}}
          <button
            type="button"
            class="btn btn-default btn-small sideloaded-inkapps-editor__remove"
            disabled={{this.saving}}
            {{on "click" this.remove}}
          >{{i18n "sideloaded_apps.inkapps.remove"}}</button>
        {{/if}}
      </div>
      {{#if this.error}}
        <span class="sideloaded-form__error">{{this.error}}</span>
      {{/if}}
      <span class="sideloaded-inkapps-editor__help">
        {{i18n "sideloaded_apps.inkapps.editor_help"}}
      </span>
    </form>
  </template>
}
