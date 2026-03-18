import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class ApkStarRating extends Component {
  get rating() {
    return this.args.rating || 0;
  }

  get interactive() {
    return this.args.interactive ?? false;
  }

  get stars() {
    return [1, 2, 3, 4, 5].map((value) => ({
      value,
      filled: value <= this.rating,
      label: `${value} star${value !== 1 ? "s" : ""}`,
    }));
  }

  @action
  selectRating(value) {
    if (this.interactive && this.args.onRate) {
      this.args.onRate(value);
    }
  }

  <template>
    <div
      class="sideloaded-star-rating {{if this.interactive 'interactive'}}"
      role="group"
      aria-label={{i18n "sideloaded_apps.stars.label"}}
    >
      {{#each this.stars as |star|}}
        {{#if this.interactive}}
          <button
            type="button"
            class="sideloaded-star {{if star.filled 'filled'}}"
            aria-label={{star.label}}
            {{on "click" (fn this.selectRating star.value)}}
          >
            {{#if star.filled}}★{{else}}☆{{/if}}
          </button>
        {{else}}
          <span
            class="sideloaded-star {{if star.filled 'filled'}}"
            aria-label={{star.label}}
          >
            {{#if star.filled}}★{{else}}☆{{/if}}
          </span>
        {{/if}}
      {{/each}}
      {{#if (and this.rating (not this.interactive))}}
        <span class="sideloaded-star-text">{{this.rating}}
          {{i18n "sideloaded_apps.stars.out_of"}}</span>
      {{/if}}
    </div>
  </template>
}
