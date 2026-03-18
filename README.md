# Discourse APK Ranking Plugin

Community-driven sideloaded app ranking system for Mudita Kompakt forum.

## Features

- **Structured app reviews** — form with app name, category, APK link, version, star rating, description, known issues, screenshots
- **Community ratings** — users rate apps when replying; average is displayed alongside author rating
- **Link verification** — automatic HTTP availability check; SHA-256 checksum consistency tracking for direct APK files
- **Link type detection** — distinguishes direct APK file links from webpage links; shows appropriate status badge ("File accessible" vs "Link accessible")
- **Report outdated version** — users can notify the author and moderators when a newer version is available
- **Top apps widget** — displays top 5 rated apps in the sidebar
- **Inline form validation** — per-field error messages with red highlighting and auto-scroll to first error on submit
- **Moderation** — uses Discourse's native approval queue

## Installation (Production — Docker)

Add to `app.yml` in the `hooks → after_code` section:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/your-org/discourse-apk-ranking.git
```

Then rebuild the container:

```bash
cd /var/discourse
./launcher rebuild app
```

Rebuild handles everything automatically: gem install, database migrations, asset compilation, service restart.

## Installation (Development)

```bash
cd /path/to/discourse/plugins
git clone https://github.com/your-org/discourse-apk-ranking.git

cd /path/to/discourse
bundle exec rake db:migrate
bin/ember-cli --proxy http://localhost:3000
```

## Configuration

Go to **Admin > Settings** and search for `apk_ranking`:

| Setting | Default | Description |
|---------|---------|-------------|
| `apk_ranking_enabled` | `true` | Enable/disable the plugin |
| `apk_ranking_category_slug` | `apk-ranking` | Slug of the category used for reviews |
| `apk_ranking_verification_enabled` | `false` | Enable automatic periodic link verification |
| `apk_ranking_verification_interval_minutes` | `30` | How often to run link verification |
| `apk_ranking_max_apk_file_size_mb` | `200` | Max file size (MB) to download for checksum verification |

## Setup Steps

1. **Install the plugin**
2. **Create the APK Ranking category** in Admin > Categories:
   - Set slug to match `apk_ranking_category_slug` (default: `apk-ranking`)
   - Enable "Require moderator approval of all new topics"
3. **Enable verification** in plugin settings if you want automatic link health checks

## Database Migrations

| File | Description |
|------|-------------|
| `20260209000001_create_apk_reviews.rb` | Main reviews table |
| `20260209000002_create_apk_votes.rb` | Votes table (superseded) |
| `20260209000003_create_apk_verifications.rb` | Link verification table |
| `20260317000001_add_link_type_to_apk_verifications.rb` | Adds `link_type` column (file vs webpage) |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/sideloaded-apps/reviews` | List all reviews |
| GET | `/sideloaded-apps/reviews/:id` | Get single review |
| POST | `/sideloaded-apps/reviews` | Create a review |
| PUT | `/sideloaded-apps/reviews/:id` | Update a review |
| POST | `/sideloaded-apps/rate` | Submit a community rating |
| POST | `/sideloaded-apps/validate-link` | Validate APK link (availability + type detection) |
| POST | `/sideloaded-apps/compute-checksum` | Compute and verify SHA-256 checksum |
| POST | `/sideloaded-apps/verify-now` | Trigger manual link verification |
| POST | `/sideloaded-apps/report-outdated` | Report an outdated app version |
| POST | `/sideloaded-apps/track-download` | Track APK download event |
| GET | `/sideloaded-apps/top` | Get top 5 rated apps |

## File Structure

```
discourse-apk-ranking/
├── plugin.rb                                         # Entry point: routes, hooks, serializer extensions
├── config/
│   ├── settings.yml                                  # Plugin settings
│   └── locales/
│       ├── client.en.yml                             # Frontend translations
│       └── server.en.yml                             # Backend translations
├── app/
│   ├── controllers/
│   │   └── apk_reviews_controller.rb                 # All API actions
│   ├── models/
│   │   ├── apk_review.rb                             # Review model
│   │   └── apk_verification.rb                       # Verification model
│   ├── serializers/
│   │   └── apk_review_serializer.rb                  # JSON serializer
│   └── jobs/scheduled/
│       └── verify_apk_links.rb                       # Scheduled verification job
├── assets/
│   ├── javascripts/discourse/
│   │   ├── api-initializers/
│   │   │   └── sideloaded-apps.gjs                   # Main frontend initializer
│   │   └── components/
│   │       ├── apk-composer-fields.gjs               # Review submission form (in composer)
│   │       ├── apk-review-display.gjs                # Review display + edit in topic
│   │       ├── apk-star-rating.gjs                   # Interactive star rating
│   │       ├── apk-verification-status.gjs           # Availability/checksum badge
│   │       └── modal/
│   │           └── report-outdated.gjs               # Report outdated version modal
│   └── stylesheets/
│       └── sideloaded-apps.scss                      # All plugin styles
├── db/
│   └── migrate/                                      # Database migrations (run automatically on rebuild)
└── spec/
    ├── fabricators/
    └── requests/
```

## Architecture Notes

- Runs entirely within Discourse — no external services required
- Link verification uses Sidekiq scheduled jobs (built into Discourse)
- Frontend uses Glimmer/Ember components (`.gjs` format)
- SHA-256 checksum is computed server-side at submission time for direct APK files; user-provided checksum is optional and used only for pre-submit verification
- Webpage links (non-direct-download) skip checksum verification and show "Link accessible" instead of "File accessible"

## License

MIT
