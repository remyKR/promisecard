/* =========================================================
   DATABASE
   ========================================================= */

CREATE DATABASE IF NOT EXISTS `their_mood`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `their_mood`;

/*
[UUID v7 적용 가이드라인]
- 모든 PK/FK `BINARY(16)` 값은 애플리케이션 단에서 UUID v7으로 생성하여 INSERT 합니다.
- 이렇게 하면 InnoDB 클러스터드 인덱스(Primary Key) 삽입이 시간순에 가까워져 성능에 유리합니다.
*/


/* =========================================================
   1) USER (Google login only)
   ========================================================= */

CREATE TABLE `user_account` (
                                `id`            BINARY(16) NOT NULL,
                                `google_sub`    VARCHAR(128) NOT NULL COMMENT 'Google sub (unique user id)',
                                `email`         VARCHAR(255) NULL,
                                `display_name`  VARCHAR(120) NULL,
                                `locale`        VARCHAR(10) NOT NULL DEFAULT 'vi',
                                `timezone`      VARCHAR(64) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',

                                `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                `revoked_at`    DATETIME NULL,

                                PRIMARY KEY (`id`),
                                UNIQUE KEY `uq_user_account_google_sub` (`google_sub`),
                                UNIQUE KEY `uq_user_account_email` (`email`),
                                KEY `idx_user_account_revoked_at` (`revoked_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- (선택) Snap(구글 드라이브) 기능을 위해 토큰 저장이 필요할 때만 사용
CREATE TABLE `user_google_oauth` (
                                     `id`               BINARY(16) NOT NULL,
                                     `user_id`          BINARY(16) NOT NULL,

                                     `access_token_enc`  TEXT NULL,
                                     `refresh_token_enc` TEXT NULL,
                                     `token_expires_at`  DATETIME NULL,
                                     `scopes`            TEXT NULL,

                                     `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at`       DATETIME NULL,

                                     PRIMARY KEY (`id`),
                                     UNIQUE KEY `uq_user_google_oauth_user_id` (`user_id`),
                                     KEY `idx_user_google_oauth_user_revoked` (`user_id`, `revoked_at`),
                                     KEY `idx_user_google_oauth_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_user_google_oauth_user`
                                         FOREIGN KEY (`user_id`) REFERENCES `user_account` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   2) MEDIA / TEMPLATE / CARD (root)
   ========================================================= */

CREATE TABLE `media_asset` (
                               `id`            BINARY(16) NOT NULL,
                               `owner_user_id` BINARY(16) NULL,

                               `kind`          VARCHAR(16) NOT NULL COMMENT 'image/video/audio/thumbnail/document/external',
                               `url`           TEXT NOT NULL,
                               `mime_type`     VARCHAR(128) NULL,
                               `bytes`         BIGINT NULL,
                               `width`         INT NULL,
                               `height`        INT NULL,
                               `duration_ms`   INT NULL,

                               `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`    DATETIME NULL,

                               CONSTRAINT `chk_media_asset_kind`
                                   CHECK (`kind` IN ('image','video','audio','thumbnail','document','external')),

                               PRIMARY KEY (`id`),
                               KEY `idx_media_asset_owner_revoked` (`owner_user_id`, `revoked_at`),
                               KEY `idx_media_asset_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_media_asset_owner`
                                   FOREIGN KEY (`owner_user_id`) REFERENCES `user_account` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `design_template` (
                                   `id`              BINARY(16) NOT NULL,
                                   `kind`            VARCHAR(32) NOT NULL DEFAULT 'invitation' COMMENT 'invitation/wedding_video/thankyou_card',
                                   `name`            VARCHAR(120) NOT NULL,
                                   `description`     TEXT NULL,
                                   `preview_media_id` BINARY(16) NULL,
                                   `config_json`     LONGTEXT NULL,
                                   `is_active`       TINYINT(1) NOT NULL DEFAULT 1,

                                   `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                   `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                   `revoked_at`      DATETIME NULL,

                                   CONSTRAINT `chk_design_template_kind`
                                       CHECK (`kind` IN ('invitation','wedding_video','thankyou_card')),

                                   PRIMARY KEY (`id`),
                                   KEY `idx_design_template_active_revoked` (`is_active`, `revoked_at`),
                                   KEY `idx_design_template_revoked_at` (`revoked_at`),
                                   KEY `idx_design_template_preview_media` (`preview_media_id`, `revoked_at`),

                                   CONSTRAINT `fk_design_template_preview_media`
                                       FOREIGN KEY (`preview_media_id`) REFERENCES `media_asset` (`id`)
                                           ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card` (
                        `id`            BINARY(16) NOT NULL,
                        `owner_user_id` BINARY(16) NOT NULL,

                        `kind`          VARCHAR(32) NOT NULL DEFAULT 'invitation' COMMENT 'invitation/wedding_video/thankyou_card',
                        `status`        VARCHAR(16) NOT NULL DEFAULT 'draft' COMMENT 'draft/published/archived',
                        `template_id`   BINARY(16) NULL,

                        `slug`          VARCHAR(120) NOT NULL COMMENT 'share url slug (unique)',
                        `share_token`   VARCHAR(128) NOT NULL COMMENT 'share token (unique)',

                        `currency`      CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',
                        `published_at`  DATETIME NULL,

                        `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                        `revoked_at`    DATETIME NULL,

                        CONSTRAINT `chk_card_kind`
                            CHECK (`kind` IN ('invitation','wedding_video','thankyou_card')),
                        CONSTRAINT `chk_card_status`
                            CHECK (`status` IN ('draft','published','archived')),
                        CONSTRAINT `chk_card_currency`
                            CHECK (`currency` IN ('KRW','USD','VND')),

                        PRIMARY KEY (`id`),
                        UNIQUE KEY `uq_card_slug` (`slug`),
                        UNIQUE KEY `uq_card_share_token` (`share_token`),
                        KEY `idx_card_owner_revoked` (`owner_user_id`, `revoked_at`),
                        KEY `idx_card_status_revoked` (`status`, `revoked_at`),
                        KEY `idx_card_template_revoked` (`template_id`, `revoked_at`),
                        KEY `idx_card_revoked_at` (`revoked_at`),

                        CONSTRAINT `fk_card_owner`
                            FOREIGN KEY (`owner_user_id`) REFERENCES `user_account` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT,
                        CONSTRAINT `fk_card_template`
                            FOREIGN KEY (`template_id`) REFERENCES `design_template` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   3) SECTION ORDER (순서 변경)
   ========================================================= */

CREATE TABLE `card_section_order` (
                                      `id`           BINARY(16) NOT NULL,
                                      `card_id`       BINARY(16) NOT NULL,
                                      `section_key`   VARCHAR(64) NOT NULL,
                                      `sort_order`    INT NOT NULL,
                                      `is_enabled`    TINYINT(1) NOT NULL DEFAULT 1,

                                      `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                      `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                      `revoked_at`    DATETIME NULL,

                                      CONSTRAINT `chk_card_section_order_sort`
                                          CHECK (`sort_order` >= 1),

                                      PRIMARY KEY (`id`),
                                      UNIQUE KEY `uq_card_section_order_key` (`card_id`, `section_key`),
                                      UNIQUE KEY `uq_card_section_order_sort` (`card_id`, `sort_order`),
                                      KEY `idx_card_section_order_card_revoked` (`card_id`, `revoked_at`),
                                      KEY `idx_card_section_order_revoked_at` (`revoked_at`),

                                      CONSTRAINT `fk_card_section_order_card`
                                          FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                              ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   4) PEOPLE / BASIC INFO (세례명 포함)
   ========================================================= */

CREATE TABLE `card_basic_info_setting` (
                                           `id`               BINARY(16) NOT NULL,
                                           `card_id`          BINARY(16) NOT NULL,

                                           `show_deceased_prefix` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '故 표시',
                                           `show_bride_first`     TINYINT(1) NOT NULL DEFAULT 0,

                                           `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                           `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                           `revoked_at`       DATETIME NULL,

                                           PRIMARY KEY (`id`),
                                           UNIQUE KEY `uq_card_basic_info_setting_card` (`card_id`),
                                           KEY `idx_card_basic_info_setting_revoked_at` (`revoked_at`),

                                           CONSTRAINT `fk_card_basic_info_setting_card`
                                               FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                   ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_person` (
                               `id`            BINARY(16) NOT NULL,
                               `card_id`       BINARY(16) NOT NULL,

                               `role`          VARCHAR(32) NOT NULL COMMENT 'groom/bride/groom_father/groom_mother/bride_father/bride_mother',
                               `family_name`   VARCHAR(80) NULL,
                               `given_name`    VARCHAR(80) NULL,
                               `display_name`  VARCHAR(200) NULL,

                               `is_deceased`   TINYINT(1) NOT NULL DEFAULT 0,
                               `baptism_name`  VARCHAR(80) NULL COMMENT '세례명',
                               `phone`         VARCHAR(40) NULL,

                               `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`    DATETIME NULL,

                               CONSTRAINT `chk_card_person_role`
                                   CHECK (`role` IN ('groom','bride','groom_father','groom_mother','bride_father','bride_mother')),

                               PRIMARY KEY (`id`),
                               UNIQUE KEY `uq_card_person_role` (`card_id`, `role`),
                               KEY `idx_card_person_card_revoked` (`card_id`, `revoked_at`),
                               KEY `idx_card_person_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_card_person_card`
                                   FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   5) MAIN COVER / OPENING ANIMATION / THUMBNAILS
   ========================================================= */

CREATE TABLE `card_main_cover` (
                                   `id`              BINARY(16) NOT NULL,
                                   `card_id`         BINARY(16) NOT NULL,

                                   `layout_variant`  VARCHAR(32) NOT NULL DEFAULT 'basic' COMMENT 'basic/fill/arch/oval/frame',
                                   `cover_media_id`  BINARY(16) NULL,

                                   `show_border_line` TINYINT(1) NOT NULL DEFAULT 0,
                                   `expand_photo`     TINYINT(1) NOT NULL DEFAULT 0,

                                   `main_phrase`      TEXT NULL,
                                   `main_phrase_effect` VARCHAR(16) NOT NULL DEFAULT 'none' COMMENT 'none/fog/wave/paper',

                                   `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                   `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                   `revoked_at`      DATETIME NULL,

                                   CONSTRAINT `chk_card_main_cover_layout`
                                       CHECK (`layout_variant` IN ('basic','fill','arch','oval','frame')),
                                   CONSTRAINT `chk_card_main_cover_effect`
                                       CHECK (`main_phrase_effect` IN ('none','fog','wave','paper')),

                                   PRIMARY KEY (`id`),
                                   UNIQUE KEY `uq_card_main_cover_card` (`card_id`),
                                   KEY `idx_card_main_cover_media_revoked` (`cover_media_id`, `revoked_at`),
                                   KEY `idx_card_main_cover_revoked_at` (`revoked_at`),

                                   CONSTRAINT `fk_card_main_cover_card`
                                       FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                           ON UPDATE RESTRICT ON DELETE RESTRICT,
                                   CONSTRAINT `fk_card_main_cover_media`
                                       FOREIGN KEY (`cover_media_id`) REFERENCES `media_asset` (`id`)
                                           ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_opening_animation` (
                                          `id`              BINARY(16) NOT NULL,
                                          `card_id`         BINARY(16) NOT NULL,

                                          `is_enabled`      TINYINT(1) NOT NULL DEFAULT 0,
                                          `variant`         VARCHAR(16) NOT NULL DEFAULT 'variant_1' COMMENT 'variant_1/variant_2',
                                          `background_color` VARCHAR(16) NULL,
                                          `overlay_opacity`  DECIMAL(4,3) NULL,
                                          `is_transparent`   TINYINT(1) NOT NULL DEFAULT 0,
                                          `ment_text`        TEXT NULL,

                                          `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                          `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                          `revoked_at`      DATETIME NULL,

                                          CONSTRAINT `chk_card_opening_variant`
                                              CHECK (`variant` IN ('variant_1','variant_2')),
                                          CONSTRAINT `chk_card_opening_opacity`
                                              CHECK (`overlay_opacity` IS NULL OR (`overlay_opacity` >= 0 AND `overlay_opacity` <= 1)),

                                          PRIMARY KEY (`id`),
                                          UNIQUE KEY `uq_card_opening_animation_card` (`card_id`),
                                          KEY `idx_card_opening_animation_revoked_at` (`revoked_at`),

                                          CONSTRAINT `fk_card_opening_animation_card`
                                              FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                  ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_share_thumbnail` (
                                        `id`             BINARY(16) NOT NULL,
                                        `card_id`        BINARY(16) NOT NULL,

                                        `platform`       VARCHAR(16) NOT NULL COMMENT 'url/kakao',
                                        `image_media_id` BINARY(16) NULL,

                                        `title`          TEXT NULL,
                                        `description`    TEXT NULL,

                                        `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                        `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                        `revoked_at`     DATETIME NULL,

                                        CONSTRAINT `chk_card_share_thumbnail_platform`
                                            CHECK (`platform` IN ('url','kakao')),

                                        PRIMARY KEY (`id`),
                                        UNIQUE KEY `uq_card_share_thumbnail_card_platform` (`card_id`, `platform`),
                                        KEY `idx_card_share_thumbnail_card_revoked` (`card_id`, `revoked_at`),
                                        KEY `idx_card_share_thumbnail_media_revoked` (`image_media_id`, `revoked_at`),
                                        KEY `idx_card_share_thumbnail_revoked_at` (`revoked_at`),

                                        CONSTRAINT `fk_card_share_thumbnail_card`
                                            FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT,
                                        CONSTRAINT `fk_card_share_thumbnail_media`
                                            FOREIGN KEY (`image_media_id`) REFERENCES `media_asset` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   6) GREETING / EVENT DATETIME / VENUE / TRANSPORT
   ========================================================= */

CREATE TABLE `card_greeting` (
                                 `id`            BINARY(16) NOT NULL,
                                 `card_id`       BINARY(16) NOT NULL,

                                 `title`         TEXT NULL,
                                 `content_html`  LONGTEXT NULL,
                                 `photo_media_id` BINARY(16) NULL,
                                 `show_names_under` TINYINT(1) NOT NULL DEFAULT 1,

                                 `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                 `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                 `revoked_at`    DATETIME NULL,

                                 PRIMARY KEY (`id`),
                                 UNIQUE KEY `uq_card_greeting_card` (`card_id`),
                                 KEY `idx_card_greeting_photo_revoked` (`photo_media_id`, `revoked_at`),
                                 KEY `idx_card_greeting_revoked_at` (`revoked_at`),

                                 CONSTRAINT `fk_card_greeting_card`
                                     FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                         ON UPDATE RESTRICT ON DELETE RESTRICT,
                                 CONSTRAINT `fk_card_greeting_photo`
                                     FOREIGN KEY (`photo_media_id`) REFERENCES `media_asset` (`id`)
                                         ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_event_datetime` (
                                       `id`              BINARY(16) NOT NULL,
                                       `card_id`         BINARY(16) NOT NULL,

                                       `event_date`      DATE NOT NULL,
                                       `event_time`      TIME NULL,
                                       `timezone`        VARCHAR(64) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',

                                       `show_calendar`      TINYINT(1) NOT NULL DEFAULT 1,
                                       `show_dday_countdown` TINYINT(1) NOT NULL DEFAULT 1,
                                       `message_html`      LONGTEXT NULL,

                                       `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at`      DATETIME NULL,

                                       PRIMARY KEY (`id`),
                                       UNIQUE KEY `uq_card_event_datetime_card` (`card_id`),
                                       KEY `idx_card_event_datetime_date` (`event_date`),
                                       KEY `idx_card_event_datetime_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_event_datetime_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_venue` (
                              `id`               BINARY(16) NOT NULL,
                              `card_id`          BINARY(16) NOT NULL,

                              `title`            TEXT NULL,
                              `country_code`     VARCHAR(8) NULL,

                              `address_line1`    TEXT NULL,
                              `address_line2`    TEXT NULL,
                              `postal_code`      VARCHAR(20) NULL,

                              `venue_name`       VARCHAR(200) NULL,
                              `hall_name`        VARCHAR(200) NULL,
                              `venue_phone`      VARCHAR(40) NULL,

                              `lat`              DECIMAL(10,7) NULL,
                              `lng`              DECIMAL(10,7) NULL,
                              `map_provider`     VARCHAR(16) NOT NULL DEFAULT 'google_maps' COMMENT 'google_maps/none',
                              `show_map`         TINYINT(1) NOT NULL DEFAULT 1,
                              `disable_map_drag` TINYINT(1) NOT NULL DEFAULT 0,
                              `show_navigation_btn` TINYINT(1) NOT NULL DEFAULT 1,
                              `map_height`       VARCHAR(16) NOT NULL DEFAULT 'default' COMMENT 'default/compact',
                              `zoom_level`       SMALLINT NOT NULL DEFAULT 15,
                              `show_street_view` TINYINT(1) NOT NULL DEFAULT 0,

                              `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                              `revoked_at`       DATETIME NULL,

                              CONSTRAINT `chk_card_venue_map_provider`
                                  CHECK (`map_provider` IN ('google_maps','none')),
                              CONSTRAINT `chk_card_venue_map_height`
                                  CHECK (`map_height` IN ('default','compact')),
                              CONSTRAINT `chk_card_venue_zoom`
                                  CHECK (`zoom_level` >= 0 AND `zoom_level` <= 22),
                              CONSTRAINT `chk_card_venue_lat`
                                  CHECK (`lat` IS NULL OR (`lat` >= -90 AND `lat` <= 90)),
                              CONSTRAINT `chk_card_venue_lng`
                                  CHECK (`lng` IS NULL OR (`lng` >= -180 AND `lng` <= 180)),

                              PRIMARY KEY (`id`),
                              UNIQUE KEY `uq_card_venue_card` (`card_id`),
                              KEY `idx_card_venue_card_revoked` (`card_id`, `revoked_at`),
                              KEY `idx_card_venue_revoked_at` (`revoked_at`),

                              CONSTRAINT `fk_card_venue_card`
                                  FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                      ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_transport_item` (
                                       `id`            BINARY(16) NOT NULL,
                                       `card_id`       BINARY(16) NOT NULL,

                                       `sort_order`    INT NOT NULL DEFAULT 1,
                                       `title`         TEXT NULL,
                                       `content_html`  LONGTEXT NULL,

                                       `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at`    DATETIME NULL,

                                       CONSTRAINT `chk_card_transport_item_sort`
                                           CHECK (`sort_order` >= 1),

                                       PRIMARY KEY (`id`),
                                       UNIQUE KEY `uq_card_transport_item_sort` (`card_id`, `sort_order`),
                                       KEY `idx_card_transport_item_card_revoked` (`card_id`, `revoked_at`),
                                       KEY `idx_card_transport_item_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_transport_item_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   7) GALLERY / VIDEO / MID PHOTO
   ========================================================= */

CREATE TABLE `card_gallery_setting` (
                                        `id`             BINARY(16) NOT NULL,
                                        `card_id`        BINARY(16) NOT NULL,

                                        `title`          TEXT NULL,
                                        `gallery_type`   VARCHAR(24) NOT NULL DEFAULT 'swipe' COMMENT 'swipe/thumbnail_swipe/grid',
                                        `open_popup_on_tap` TINYINT(1) NOT NULL DEFAULT 1,
                                        `allow_zoom_in_popup` TINYINT(1) NOT NULL DEFAULT 0,

                                        `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                        `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                        `revoked_at`     DATETIME NULL,

                                        CONSTRAINT `chk_card_gallery_setting_type`
                                            CHECK (`gallery_type` IN ('swipe','thumbnail_swipe','grid')),

                                        PRIMARY KEY (`id`),
                                        UNIQUE KEY `uq_card_gallery_setting_card` (`card_id`),
                                        KEY `idx_card_gallery_setting_revoked_at` (`revoked_at`),

                                        CONSTRAINT `fk_card_gallery_setting_card`
                                            FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_gallery_photo` (
                                      `id`          BINARY(16) NOT NULL,
                                      `card_id`     BINARY(16) NOT NULL,
                                      `media_id`    BINARY(16) NOT NULL,

                                      `sort_order`  INT NOT NULL DEFAULT 1,
                                      `caption`     TEXT NULL,

                                      `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                      `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                      `revoked_at`  DATETIME NULL,

                                      CONSTRAINT `chk_card_gallery_photo_sort`
                                          CHECK (`sort_order` >= 1),

                                      PRIMARY KEY (`id`),
                                      UNIQUE KEY `uq_card_gallery_photo_sort` (`card_id`, `sort_order`),
                                      KEY `idx_card_gallery_photo_card_revoked` (`card_id`, `revoked_at`),
                                      KEY `idx_card_gallery_photo_media_revoked` (`media_id`, `revoked_at`),
                                      KEY `idx_card_gallery_photo_revoked_at` (`revoked_at`),

                                      CONSTRAINT `fk_card_gallery_photo_card`
                                          FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                              ON UPDATE RESTRICT ON DELETE RESTRICT,
                                      CONSTRAINT `fk_card_gallery_photo_media`
                                          FOREIGN KEY (`media_id`) REFERENCES `media_asset` (`id`)
                                              ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_video` (
                              `id`           BINARY(16) NOT NULL,
                              `card_id`      BINARY(16) NOT NULL,

                              `title`        TEXT NULL,
                              `youtube_url`  TEXT NULL,
                              `aspect_ratio` VARCHAR(16) NOT NULL DEFAULT 'default' COMMENT 'default/16:9/9:16/1:1',

                              `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                              `revoked_at`   DATETIME NULL,

                              CONSTRAINT `chk_card_video_aspect`
                                  CHECK (`aspect_ratio` IN ('default','16:9','9:16','1:1')),

                              PRIMARY KEY (`id`),
                              UNIQUE KEY `uq_card_video_card` (`card_id`),
                              KEY `idx_card_video_revoked_at` (`revoked_at`),

                              CONSTRAINT `fk_card_video_card`
                                  FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                      ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_mid_photo` (
                                  `id`         BINARY(16) NOT NULL,
                                  `card_id`    BINARY(16) NOT NULL,
                                  `media_id`   BINARY(16) NULL,

                                  `effect`     VARCHAR(16) NOT NULL DEFAULT 'none' COMMENT 'none/fog/wave/paper',

                                  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                  `revoked_at` DATETIME NULL,

                                  CONSTRAINT `chk_card_mid_photo_effect`
                                      CHECK (`effect` IN ('none','fog','wave','paper')),

                                  PRIMARY KEY (`id`),
                                  UNIQUE KEY `uq_card_mid_photo_card` (`card_id`),
                                  KEY `idx_card_mid_photo_media_revoked` (`media_id`, `revoked_at`),
                                  KEY `idx_card_mid_photo_revoked_at` (`revoked_at`),

                                  CONSTRAINT `fk_card_mid_photo_card`
                                      FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                          ON UPDATE RESTRICT ON DELETE RESTRICT,
                                  CONSTRAINT `fk_card_mid_photo_media`
                                      FOREIGN KEY (`media_id`) REFERENCES `media_asset` (`id`)
                                          ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   8) BACKGROUND MUSIC
   ========================================================= */

CREATE TABLE `music_track` (
                               `id`            BINARY(16) NOT NULL,
                               `name`          VARCHAR(200) NOT NULL,
                               `artist`        VARCHAR(200) NULL,
                               `audio_media_id` BINARY(16) NULL,
                               `external_url`  TEXT NULL,
                               `is_active`     TINYINT(1) NOT NULL DEFAULT 1,

                               `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`    DATETIME NULL,

                               PRIMARY KEY (`id`),
                               KEY `idx_music_track_active_revoked` (`is_active`, `revoked_at`),
                               KEY `idx_music_track_audio_revoked` (`audio_media_id`, `revoked_at`),
                               KEY `idx_music_track_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_music_track_audio_media`
                                   FOREIGN KEY (`audio_media_id`) REFERENCES `media_asset` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_background_music` (
                                         `id`             BINARY(16) NOT NULL,
                                         `card_id`        BINARY(16) NOT NULL,

                                         `track_id`       BINARY(16) NULL,
                                         `custom_audio_url` TEXT NULL,
                                         `autoplay`       TINYINT(1) NOT NULL DEFAULT 0,

                                         `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                         `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                         `revoked_at`     DATETIME NULL,

                                         CONSTRAINT `chk_card_background_music_source`
                                             CHECK (
                                                 (`track_id` IS NOT NULL AND `custom_audio_url` IS NULL)
                                                     OR (`track_id` IS NULL AND `custom_audio_url` IS NOT NULL)
                                                     OR (`track_id` IS NULL AND `custom_audio_url` IS NULL)
                                                 ),

                                         PRIMARY KEY (`id`),
                                         UNIQUE KEY `uq_card_background_music_card` (`card_id`),
                                         KEY `idx_card_background_music_track_revoked` (`track_id`, `revoked_at`),
                                         KEY `idx_card_background_music_revoked_at` (`revoked_at`),

                                         CONSTRAINT `fk_card_background_music_card`
                                             FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                 ON UPDATE RESTRICT ON DELETE RESTRICT,
                                         CONSTRAINT `fk_card_background_music_track`
                                             FOREIGN KEY (`track_id`) REFERENCES `music_track` (`id`)
                                                 ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   9) CONTACT / DONATION / GUESTBOOK / RSVP
   ========================================================= */

CREATE TABLE `card_contact_setting` (
                                        `id`         BINARY(16) NOT NULL,
                                        `card_id`    BINARY(16) NOT NULL,

                                        `is_enabled`        TINYINT(1) NOT NULL DEFAULT 1,
                                        `show_groom`        TINYINT(1) NOT NULL DEFAULT 1,
                                        `show_bride`        TINYINT(1) NOT NULL DEFAULT 1,
                                        `show_groom_father` TINYINT(1) NOT NULL DEFAULT 1,
                                        `show_groom_mother` TINYINT(1) NOT NULL DEFAULT 1,
                                        `show_bride_father` TINYINT(1) NOT NULL DEFAULT 1,
                                        `show_bride_mother` TINYINT(1) NOT NULL DEFAULT 1,

                                        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                        `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                        `revoked_at` DATETIME NULL,

                                        PRIMARY KEY (`id`),
                                        UNIQUE KEY `uq_card_contact_setting_card` (`card_id`),
                                        KEY `idx_card_contact_setting_revoked_at` (`revoked_at`),

                                        CONSTRAINT `fk_card_contact_setting_card`
                                            FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_donation_setting` (
                                         `id`         BINARY(16) NOT NULL,
                                         `card_id`    BINARY(16) NOT NULL,

                                         `title`      TEXT NULL,
                                         `content_html` LONGTEXT NULL,
                                         `display_type` VARCHAR(16) NOT NULL DEFAULT 'accordion' COMMENT 'accordion/swipe',

                                         `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                         `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                         `revoked_at` DATETIME NULL,

                                         CONSTRAINT `chk_card_donation_display_type`
                                             CHECK (`display_type` IN ('accordion','swipe')),

                                         PRIMARY KEY (`id`),
                                         UNIQUE KEY `uq_card_donation_setting_card` (`card_id`),
                                         KEY `idx_card_donation_setting_revoked_at` (`revoked_at`),

                                         CONSTRAINT `fk_card_donation_setting_card`
                                             FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                 ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_donation_group` (
                                       `id`         BINARY(16) NOT NULL,
                                       `card_id`    BINARY(16) NOT NULL,

                                       `sort_order` INT NOT NULL DEFAULT 1,
                                       `title`      TEXT NULL,
                                       `is_collapsed` TINYINT(1) NOT NULL DEFAULT 1,

                                       `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at` DATETIME NULL,

                                       CONSTRAINT `chk_card_donation_group_sort`
                                           CHECK (`sort_order` >= 1),

                                       PRIMARY KEY (`id`),
                                       UNIQUE KEY `uq_card_donation_group_sort` (`card_id`, `sort_order`),
                                       KEY `idx_card_donation_group_card_revoked` (`card_id`, `revoked_at`),
                                       KEY `idx_card_donation_group_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_donation_group_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_donation_account` (
                                         `id`          BINARY(16) NOT NULL,
                                         `group_id`    BINARY(16) NOT NULL,

                                         `sort_order`  INT NOT NULL DEFAULT 1,
                                         `account_holder` VARCHAR(120) NULL,
                                         `bank_name`   VARCHAR(120) NULL,
                                         `account_number` VARCHAR(120) NULL,

                                         `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                         `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                         `revoked_at`  DATETIME NULL,

                                         CONSTRAINT `chk_card_donation_account_sort`
                                             CHECK (`sort_order` >= 1),

                                         PRIMARY KEY (`id`),
                                         UNIQUE KEY `uq_card_donation_account_sort` (`group_id`, `sort_order`),
                                         KEY `idx_card_donation_account_group_revoked` (`group_id`, `revoked_at`),
                                         KEY `idx_card_donation_account_revoked_at` (`revoked_at`),

                                         CONSTRAINT `fk_card_donation_account_group`
                                             FOREIGN KEY (`group_id`) REFERENCES `card_donation_group` (`id`)
                                                 ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_guestbook_setting` (
                                          `id`         BINARY(16) NOT NULL,
                                          `card_id`    BINARY(16) NOT NULL,

                                          `title`      TEXT NULL,
                                          `entry_visibility` VARCHAR(16) NOT NULL DEFAULT 'public' COMMENT 'public/private',
                                          `design_type` VARCHAR(16) NOT NULL DEFAULT 'basic' COMMENT 'basic/postit/button_popup',
                                          `hide_entry_date` TINYINT(1) NOT NULL DEFAULT 0,

                                          `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                          `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                          `revoked_at` DATETIME NULL,

                                          CONSTRAINT `chk_card_guestbook_visibility`
                                              CHECK (`entry_visibility` IN ('public','private')),
                                          CONSTRAINT `chk_card_guestbook_design_type`
                                              CHECK (`design_type` IN ('basic','postit','button_popup')),

                                          PRIMARY KEY (`id`),
                                          UNIQUE KEY `uq_card_guestbook_setting_card` (`card_id`),
                                          KEY `idx_card_guestbook_setting_revoked_at` (`revoked_at`),

                                          CONSTRAINT `fk_card_guestbook_setting_card`
                                              FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                  ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_guestbook_entry` (
                                        `id`         BINARY(16) NOT NULL,
                                        `card_id`    BINARY(16) NOT NULL,

                                        `author_name` VARCHAR(120) NOT NULL,
                                        `author_phone` VARCHAR(40) NULL,
                                        `message_html` LONGTEXT NOT NULL,

                                        `delete_password_hash` VARCHAR(255) NULL,
                                        `delete_password_salt` VARCHAR(255) NULL,

                                        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                        `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                        `revoked_at` DATETIME NULL,

                                        PRIMARY KEY (`id`),
                                        KEY `idx_card_guestbook_entry_card_created` (`card_id`, `created_at`),
                                        KEY `idx_card_guestbook_entry_card_revoked` (`card_id`, `revoked_at`),
                                        KEY `idx_card_guestbook_entry_revoked_at` (`revoked_at`),

                                        CONSTRAINT `fk_card_guestbook_entry_card`
                                            FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_rsvp_setting` (
                                     `id`         BINARY(16) NOT NULL,
                                     `card_id`    BINARY(16) NOT NULL,

                                     `title`      TEXT NULL,
                                     `content_html` LONGTEXT NULL,
                                     `button_label` TEXT NULL,

                                     `include_guest_count`   TINYINT(1) NOT NULL DEFAULT 1,
                                     `include_phone`         TINYINT(1) NOT NULL DEFAULT 1,
                                     `include_meal`          TINYINT(1) NOT NULL DEFAULT 1,
                                     `include_extra_message` TINYINT(1) NOT NULL DEFAULT 1,
                                     `include_bus`           TINYINT(1) NOT NULL DEFAULT 0,

                                     `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at` DATETIME NULL,

                                     PRIMARY KEY (`id`),
                                     UNIQUE KEY `uq_card_rsvp_setting_card` (`card_id`),
                                     KEY `idx_card_rsvp_setting_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_card_rsvp_setting_card`
                                         FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_rsvp_response` (
                                      `id`              BINARY(16) NOT NULL,
                                      `card_id`         BINARY(16) NOT NULL,

                                      `respondent_name` VARCHAR(120) NOT NULL,
                                      `phone`           VARCHAR(40) NULL,
                                      `guest_count`     INT NULL,
                                      `meal_option`     VARCHAR(16) NULL COMMENT 'yes/no/undecided',
                                      `bus_ride`        TINYINT(1) NULL,
                                      `extra_message`   TEXT NULL,

                                      `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                      `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                      `revoked_at`      DATETIME NULL,

                                      CONSTRAINT `chk_card_rsvp_response_guest_count`
                                          CHECK (`guest_count` IS NULL OR `guest_count` >= 0),
                                      CONSTRAINT `chk_card_rsvp_response_meal_option`
                                          CHECK (`meal_option` IS NULL OR `meal_option` IN ('yes','no','undecided')),

                                      PRIMARY KEY (`id`),
                                      KEY `idx_card_rsvp_response_card_created` (`card_id`, `created_at`),
                                      KEY `idx_card_rsvp_response_card_revoked` (`card_id`, `revoked_at`),
                                      KEY `idx_card_rsvp_response_revoked_at` (`revoked_at`),

                                      CONSTRAINT `fk_card_rsvp_response_card`
                                          FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                              ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   10) INTERVIEW / NOTICE
   ========================================================= */

CREATE TABLE `card_interview_setting` (
                                          `id`         BINARY(16) NOT NULL,
                                          `card_id`    BINARY(16) NOT NULL,

                                          `title`      TEXT NULL,
                                          `content_html` LONGTEXT NULL,
                                          `groom_photo_media_id` BINARY(16) NULL,
                                          `bride_photo_media_id` BINARY(16) NULL,

                                          `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                          `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                          `revoked_at` DATETIME NULL,

                                          PRIMARY KEY (`id`),
                                          UNIQUE KEY `uq_card_interview_setting_card` (`card_id`),
                                          KEY `idx_card_interview_setting_revoked_at` (`revoked_at`),

                                          CONSTRAINT `fk_card_interview_setting_card`
                                              FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                  ON UPDATE RESTRICT ON DELETE RESTRICT,
                                          CONSTRAINT `fk_card_interview_setting_groom_photo`
                                              FOREIGN KEY (`groom_photo_media_id`) REFERENCES `media_asset` (`id`)
                                                  ON UPDATE RESTRICT ON DELETE RESTRICT,
                                          CONSTRAINT `fk_card_interview_setting_bride_photo`
                                              FOREIGN KEY (`bride_photo_media_id`) REFERENCES `media_asset` (`id`)
                                                  ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_interview_item` (
                                       `id`         BINARY(16) NOT NULL,
                                       `card_id`    BINARY(16) NOT NULL,

                                       `sort_order` INT NOT NULL DEFAULT 1,
                                       `question`   TEXT NULL,
                                       `answer`     TEXT NULL,

                                       `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at` DATETIME NULL,

                                       CONSTRAINT `chk_card_interview_item_sort`
                                           CHECK (`sort_order` >= 1),

                                       PRIMARY KEY (`id`),
                                       UNIQUE KEY `uq_card_interview_item_sort` (`card_id`, `sort_order`),
                                       KEY `idx_card_interview_item_card_revoked` (`card_id`, `revoked_at`),
                                       KEY `idx_card_interview_item_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_interview_item_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_notice_group` (
                                     `id`         BINARY(16) NOT NULL,
                                     `card_id`    BINARY(16) NOT NULL,

                                     `group_type` VARCHAR(16) NOT NULL DEFAULT 'grouped' COMMENT 'grouped/separate',
                                     `sort_order` INT NOT NULL DEFAULT 1,
                                     `title`      TEXT NULL,

                                     `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at` DATETIME NULL,

                                     CONSTRAINT `chk_card_notice_group_type`
                                         CHECK (`group_type` IN ('grouped','separate')),
                                     CONSTRAINT `chk_card_notice_group_sort`
                                         CHECK (`sort_order` >= 1),

                                     PRIMARY KEY (`id`),
                                     UNIQUE KEY `uq_card_notice_group_sort` (`card_id`, `sort_order`),
                                     KEY `idx_card_notice_group_card_revoked` (`card_id`, `revoked_at`),
                                     KEY `idx_card_notice_group_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_card_notice_group_card`
                                         FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_notice_item` (
                                    `id`        BINARY(16) NOT NULL,
                                    `group_id`  BINARY(16) NOT NULL,

                                    `sort_order` INT NOT NULL DEFAULT 1,
                                    `title`     TEXT NULL,
                                    `content_html` LONGTEXT NULL,
                                    `is_sample` TINYINT(1) NOT NULL DEFAULT 0,

                                    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `revoked_at` DATETIME NULL,

                                    CONSTRAINT `chk_card_notice_item_sort`
                                        CHECK (`sort_order` >= 1),

                                    PRIMARY KEY (`id`),
                                    UNIQUE KEY `uq_card_notice_item_sort` (`group_id`, `sort_order`),
                                    KEY `idx_card_notice_item_group_revoked` (`group_id`, `revoked_at`),
                                    KEY `idx_card_notice_item_revoked_at` (`revoked_at`),

                                    CONSTRAINT `fk_card_notice_item_group`
                                        FOREIGN KEY (`group_id`) REFERENCES `card_notice_group` (`id`)
                                            ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   11) WREATH (축하화환 보내기 / 목록) + CURRENCY
   ========================================================= */

CREATE TABLE `wreath_item` (
                               `id`          BINARY(16) NOT NULL,
                               `name`        VARCHAR(200) NOT NULL,
                               `description` TEXT NULL,
                               `image_media_id` BINARY(16) NULL,

                               `base_price`  DECIMAL(15,2) NOT NULL DEFAULT 0,
                               `currency`    CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',
                               `is_active`   TINYINT(1) NOT NULL DEFAULT 1,

                               `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`  DATETIME NULL,

                               CONSTRAINT `chk_wreath_item_base_price`
                                   CHECK (`base_price` >= 0),
                               CONSTRAINT `chk_wreath_item_currency`
                                   CHECK (`currency` IN ('KRW','USD','VND')),

                               PRIMARY KEY (`id`),
                               KEY `idx_wreath_item_active_revoked` (`is_active`, `revoked_at`),
                               KEY `idx_wreath_item_media_revoked` (`image_media_id`, `revoked_at`),
                               KEY `idx_wreath_item_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_wreath_item_media`
                                   FOREIGN KEY (`image_media_id`) REFERENCES `media_asset` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_wreath_setting` (
                                       `id`          BINARY(16) NOT NULL,
                                       `card_id`     BINARY(16) NOT NULL,

                                       `is_enabled`  TINYINT(1) NOT NULL DEFAULT 0,
                                       `display_mode` VARCHAR(16) NOT NULL DEFAULT 'floating_menu' COMMENT 'floating_menu/banner',
                                       `show_wreath_list` TINYINT(1) NOT NULL DEFAULT 1,

                                       `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at`  DATETIME NULL,

                                       CONSTRAINT `chk_card_wreath_display_mode`
                                           CHECK (`display_mode` IN ('floating_menu','banner')),

                                       PRIMARY KEY (`id`),
                                       UNIQUE KEY `uq_card_wreath_setting_card` (`card_id`),
                                       KEY `idx_card_wreath_setting_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_wreath_setting_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_wreath_order` (
                                     `id`            BINARY(16) NOT NULL,
                                     `card_id`       BINARY(16) NOT NULL,
                                     `wreath_item_id` BINARY(16) NULL,

                                     `buyer_name`    VARCHAR(120) NOT NULL,
                                     `buyer_phone`   VARCHAR(40) NULL,
                                     `message`       TEXT NULL,
                                     `display_on_card` TINYINT(1) NOT NULL DEFAULT 1,

                                     `price_paid`    DECIMAL(15,2) NULL,
                                     `currency`      CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',
                                     `payment_status` VARCHAR(16) NOT NULL DEFAULT 'pending' COMMENT 'pending/paid/failed/refunded/cancelled',
                                     `payment_ref`   VARCHAR(200) NULL,

                                     `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at`    DATETIME NULL,

                                     CONSTRAINT `chk_card_wreath_order_currency`
                                         CHECK (`currency` IN ('KRW','USD','VND')),
                                     CONSTRAINT `chk_card_wreath_order_payment_status`
                                         CHECK (`payment_status` IN ('pending','paid','failed','refunded','cancelled')),
                                     CONSTRAINT `chk_card_wreath_order_price_paid`
                                         CHECK (`price_paid` IS NULL OR `price_paid` >= 0),

                                     PRIMARY KEY (`id`),
                                     KEY `idx_card_wreath_order_card_created` (`card_id`, `created_at`),
                                     KEY `idx_card_wreath_order_card_revoked` (`card_id`, `revoked_at`),
                                     KEY `idx_card_wreath_order_item_revoked` (`wreath_item_id`, `revoked_at`),
                                     KEY `idx_card_wreath_order_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_card_wreath_order_card`
                                         FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT,
                                     CONSTRAINT `fk_card_wreath_order_item`
                                         FOREIGN KEY (`wreath_item_id`) REFERENCES `wreath_item` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   12) SNAP (Google Drive)
   ========================================================= */

CREATE TABLE `card_snap_setting` (
                                     `id`            BINARY(16) NOT NULL,
                                     `card_id`       BINARY(16) NOT NULL,

                                     `is_enabled`    TINYINT(1) NOT NULL DEFAULT 0,
                                     `drive_folder_id`   VARCHAR(200) NULL,
                                     `drive_folder_name` VARCHAR(200) NULL,
                                     `title`         TEXT NULL,
                                     `description`   TEXT NULL,

                                     `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at`    DATETIME NULL,

                                     PRIMARY KEY (`id`),
                                     UNIQUE KEY `uq_card_snap_setting_card` (`card_id`),
                                     KEY `idx_card_snap_setting_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_card_snap_setting_card`
                                         FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `card_snap_upload` (
                                    `id`            BINARY(16) NOT NULL,
                                    `card_id`       BINARY(16) NOT NULL,

                                    `uploader_name` VARCHAR(120) NULL,
                                    `uploader_phone` VARCHAR(40) NULL,

                                    `provider_file_id` VARCHAR(200) NULL COMMENT 'Google Drive fileId',
                                    `provider_web_url` TEXT NULL,
                                    `file_name`     VARCHAR(255) NULL,
                                    `mime_type`     VARCHAR(128) NULL,
                                    `bytes`         BIGINT NULL,

                                    `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `revoked_at`    DATETIME NULL,

                                    PRIMARY KEY (`id`),
                                    KEY `idx_card_snap_upload_card_created` (`card_id`, `created_at`),
                                    KEY `idx_card_snap_upload_card_revoked` (`card_id`, `revoked_at`),
                                    KEY `idx_card_snap_upload_file_id` (`provider_file_id`),
                                    KEY `idx_card_snap_upload_revoked_at` (`revoked_at`),

                                    CONSTRAINT `fk_card_snap_upload_card`
                                        FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                            ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
