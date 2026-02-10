/* =========================================================
   PART 0) DATABASE
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

/*
[설계 핵심 원칙]
1) 1:1 "설정/렌더링 전용" 데이터는 JOIN 비용을 줄이기 위해 `card.config_json`으로 통합합니다.
   - 예: main_cover, opening_animation, greeting, venue, gallery_setting, video, mid_photo, background_music,
         contact_setting, donation_setting, guestbook_setting, rsvp_setting, interview_setting,
         wreath_setting, snap_setting, section_order, share_thumbnail 등
2) 1:N 또는 데이터가 많이 쌓이는 영역은 테이블로 유지합니다.
   - 예: gallery_photo, guestbook_entry, rsvp_response, notice_group/item, donation_group/account,
         transport_item, wreath_order, payment_event_log, snap_upload 등
3) 공용 카탈로그 성격의 데이터는 테이블로 유지합니다.
   - 예: music_track, wreath_item, design_template
4) Money(금액)는 Minor unit 정수(BIGINT)로 저장합니다.
   - 예: VND(1=1동), KRW(1=1원), USD(100=1달러 센트)
*/

/* =========================================================
   PART 1) USER & AUTH
   ========================================================= */

/* [Table 01] user_account - 사용자 기본 정보 (Google 로그인 기반) */
CREATE TABLE `user_account` (
                                `id`            BINARY(16) NOT NULL,
                                `google_sub`    VARCHAR(128) NOT NULL COMMENT 'Google sub (unique user id)',
                                `email`         VARCHAR(255) NULL,
                                `display_name`  VARCHAR(120) NULL,
                                `locale`        VARCHAR(10)  NOT NULL DEFAULT 'vi',
                                `timezone`      VARCHAR(64)  NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',

                                `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                `revoked_at`    DATETIME NULL,

                                PRIMARY KEY (`id`),
                                UNIQUE KEY `uq_user_account_google_sub` (`google_sub`),
                                UNIQUE KEY `uq_user_account_email` (`email`),
                                KEY `idx_user_account_revoked_at` (`revoked_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* [Table 02] user_google_oauth - (선택) Snap/구글드라이브 연동용 OAuth 토큰 저장 (App 레벨 암호화 전제) */
CREATE TABLE `user_google_oauth` (
                                     `id`                BINARY(16) NOT NULL,
                                     `user_id`            BINARY(16) NOT NULL,

                                     `access_token_enc`   TEXT NULL COMMENT 'App 레벨 암호화 필수',
                                     `refresh_token_enc`  TEXT NULL COMMENT 'App 레벨 암호화 필수',
                                     `token_expires_at`   DATETIME NULL,
                                     `scopes`             TEXT NULL,

                                     `created_at`         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at`         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at`         DATETIME NULL,

                                     PRIMARY KEY (`id`),
                                     UNIQUE KEY `uq_user_google_oauth_user_id` (`user_id`),
                                     KEY `idx_user_google_oauth_user_revoked` (`user_id`, `revoked_at`),
                                     KEY `idx_user_google_oauth_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_user_google_oauth_user`
                                         FOREIGN KEY (`user_id`) REFERENCES `user_account` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 2) MEDIA
   ========================================================= */

/* [Table 03] media_asset - 업로드 미디어 메타데이터 (S3 최적화: bucket/object_key 저장) */
CREATE TABLE `media_asset` (
                               `id`              BINARY(16) NOT NULL,
                               `owner_user_id`   BINARY(16) NULL,

                               `storage_provider` VARCHAR(16) NOT NULL DEFAULT 'S3' COMMENT 'S3/EXTERNAL',
                               `bucket`          VARCHAR(64)  NULL COMMENT 'S3 Bucket Name',
                               `object_key`      VARCHAR(512) NULL COMMENT 'S3 Object Key (File Path)',
                               `url`             TEXT NULL COMMENT 'CDN/CloudFront URL (캐시용, 변경 가능)',

                               `kind`            VARCHAR(16) NOT NULL COMMENT 'image/video/audio/thumbnail/document/external',
                               `mime_type`       VARCHAR(128) NULL,
                               `bytes`           BIGINT NULL,
                               `width`           INT NULL,
                               `height`          INT NULL,
                               `duration_ms`     INT NULL,

                               `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`      DATETIME NULL,

                               CONSTRAINT `chk_media_asset_provider`
                                   CHECK (`storage_provider` IN ('S3','EXTERNAL')),
                               CONSTRAINT `chk_media_asset_kind`
                                   CHECK (`kind` IN ('image','video','audio','thumbnail','document','external')),

                               PRIMARY KEY (`id`),
                               KEY `idx_media_asset_owner_revoked` (`owner_user_id`, `revoked_at`),
                               KEY `idx_media_asset_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_media_asset_owner`
                                   FOREIGN KEY (`owner_user_id`) REFERENCES `user_account` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 3) TEMPLATE / MUSIC CATALOG
   ========================================================= */

/* [Table 04] design_template - 디자인 템플릿(프리셋), 카드가 선택해 사용 */
CREATE TABLE `design_template` (
                                   `id`               BINARY(16) NOT NULL,
                                   `kind`             VARCHAR(32) NOT NULL DEFAULT 'invitation' COMMENT 'invitation/wedding_video/thankyou_card',
                                   `name`             VARCHAR(120) NOT NULL,
                                   `description`      TEXT NULL,
                                   `preview_media_id` BINARY(16) NULL,

                                   `default_config_json` LONGTEXT NULL CHECK (JSON_VALID(`default_config_json`)),
                                   `is_active`        TINYINT(1) NOT NULL DEFAULT 1,

                                   `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                   `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                   `revoked_at`       DATETIME NULL,

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

/* [Table 05] music_track - 배경음악 공용 카탈로그(관리/검색/활성화 필요하므로 테이블 유지) */
CREATE TABLE `music_track` (
                               `id`             BINARY(16) NOT NULL,
                               `name`           VARCHAR(200) NOT NULL,
                               `artist`         VARCHAR(200) NULL,
                               `audio_media_id` BINARY(16) NULL,
                               `external_url`   TEXT NULL,
                               `is_active`      TINYINT(1) NOT NULL DEFAULT 1,

                               `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`     DATETIME NULL,

                               PRIMARY KEY (`id`),
                               KEY `idx_music_track_active_revoked` (`is_active`, `revoked_at`),
                               KEY `idx_music_track_audio_revoked` (`audio_media_id`, `revoked_at`),
                               KEY `idx_music_track_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_music_track_audio_media`
                                   FOREIGN KEY (`audio_media_id`) REFERENCES `media_asset` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 4) CARD (CORE) - 설정 통합(JSON)
   ========================================================= */

/* [Table 06] card - 카드 핵심(검색/정렬용 컬럼 + 모든 1:1 설정은 config_json) */
CREATE TABLE `card` (
                        `id`             BINARY(16) NOT NULL,
                        `owner_user_id`  BINARY(16) NOT NULL,

                        `kind`           VARCHAR(32) NOT NULL DEFAULT 'invitation' COMMENT 'invitation/wedding_video/thankyou_card',
                        `status`         VARCHAR(16) NOT NULL DEFAULT 'draft' COMMENT 'draft/published/archived',
                        `template_id`    BINARY(16) NULL,

                        `slug`           VARCHAR(120) NOT NULL COMMENT 'share url slug (unique)',
                        `share_token`    VARCHAR(128) NOT NULL COMMENT 'share token (unique)',

    /* 검색/정렬/필터링에 필요한 핵심 컬럼 */
                        `title`          VARCHAR(255) NOT NULL DEFAULT 'We are getting married',
                        `event_at`       DATETIME NULL COMMENT '검색/정렬용 (예식 일시)',
                        `event_timezone` VARCHAR(64) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh' COMMENT '표시/변환용 타임존',
                        `area_code`      VARCHAR(50) NULL COMMENT 'Hanoi/HCMC/Seoul etc.',
                        `currency`       CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',
                        `published_at`   DATETIME NULL,

    /* 핵심: 1:1 설정/렌더링 데이터 통합 */
                        `config_json`    LONGTEXT NULL CHECK (JSON_VALID(`config_json`)) COMMENT '1:1 설정 통합(JSON)',

    /*
    [config_json 예시 구조 - 필요한 것만 채우는 방식]
    {
      "section_order": ["main_cover","greeting","event","venue","gallery","video","donation","guestbook","rsvp","notice","snap","wreath"],
      "basic_info": {
        "show_deceased_prefix": true,
        "show_bride_first": false
      },
      "main_cover": {
        "layout_variant": "basic",
        "cover_media_id": "BINARY(16)",
        "show_border_line": false,
        "expand_photo": false,
        "main_phrase": "...",
        "main_phrase_effect": "none"
      },
      "opening_animation": {
        "is_enabled": false,
        "variant": "variant_1",
        "background_color": "#000000",
        "overlay_opacity": 0.6,
        "is_transparent": false,
        "ment_text": "..."
      },
      "share_thumbnails": [
        { "platform": "url", "image_media_id": "BINARY(16)", "title": "...", "description": "..." },
        { "platform": "kakao", "image_media_id": "BINARY(16)", "title": "...", "description": "..." }
      ],
      "greeting": {
        "title": "...",
        "content_html": "...",
        "photo_media_id": "BINARY(16)",
        "show_names_under": true
      },
      "event": {
        "event_date": "2026-02-10",
        "event_time": "12:30:00",
        "show_calendar": true,
        "show_dday_countdown": true,
        "message_html": "..."
      },
      "venue": {
        "title": "...",
        "country_code": "VN",
        "address_line1": "...",
        "address_line2": "...",
        "postal_code": "...",
        "venue_name": "...",
        "hall_name": "...",
        "venue_phone": "...",
        "lat": 10.1234567,
        "lng": 106.1234567,
        "map_provider": "google_maps",
        "show_map": true,
        "disable_map_drag": false,
        "show_navigation_btn": true,
        "map_height": "default",
        "zoom_level": 15,
        "show_street_view": false
      },
      "gallery_setting": {
        "title": "...",
        "gallery_type": "swipe",
        "open_popup_on_tap": true,
        "allow_zoom_in_popup": false
      },
      "video": {
        "is_enabled": true,
        "title": "...",
        "youtube_url": "...",
        "aspect_ratio": "16:9"
      },
      "mid_photo": {
        "media_id": "BINARY(16)",
        "effect": "none"
      },
      "background_music": {
        "autoplay": false,
        "track_id": "BINARY(16)",
        "custom_audio_url": null,
        "track_snapshot": { "name": "...", "artist": "...", "audio_url": "..." }
      },
      "contact_setting": {
        "is_enabled": true,
        "show_groom": true,
        "show_bride": true,
        "show_groom_father": true,
        "show_groom_mother": true,
        "show_bride_father": true,
        "show_bride_mother": true
      },
      "donation_setting": {
        "title": "...",
        "content_html": "...",
        "display_type": "accordion"
      },
      "guestbook_setting": {
        "title": "...",
        "entry_visibility": "public",
        "design_type": "basic",
        "hide_entry_date": false
      },
      "rsvp_setting": {
        "title": "...",
        "content_html": "...",
        "button_label": "...",
        "include_guest_count": true,
        "include_phone": true,
        "include_meal": true,
        "include_extra_message": true,
        "include_bus": false
      },
      "interview_setting": {
        "title": "...",
        "content_html": "...",
        "groom_photo_media_id": "BINARY(16)",
        "bride_photo_media_id": "BINARY(16)"
      },
      "wreath_setting": {
        "is_enabled": false,
        "display_mode": "floating_menu",
        "show_wreath_list": true
      },
      "snap_setting": {
        "is_enabled": false,
        "drive_folder_id": "...",
        "drive_folder_name": "...",
        "title": "...",
        "description": "..."
      }
    }
    */

                        `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                        `revoked_at`     DATETIME NULL,

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
                        KEY `idx_card_event_at` (`event_at`),
                        KEY `idx_card_revoked_at` (`revoked_at`),

                        CONSTRAINT `fk_card_owner`
                            FOREIGN KEY (`owner_user_id`) REFERENCES `user_account` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT,
                        CONSTRAINT `fk_card_template`
                            FOREIGN KEY (`template_id`) REFERENCES `design_template` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 5) CARD CONTENT LIST (1:N 유지)
   ========================================================= */

/* [Table 07] card_person - 인물 정보(신랑/신부/부/모 등), 카드별 역할 1개씩 */
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

/* [Table 08] card_transport_item - 교통편 안내(정렬 가능한 리스트) */
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

/* [Table 09] card_gallery_photo - 갤러리 사진(대량/정렬/추가삭제 빈번) */
CREATE TABLE `card_gallery_photo` (
                                      `id`           BINARY(16) NOT NULL,
                                      `card_id`      BINARY(16) NOT NULL,
                                      `media_id`     BINARY(16) NOT NULL,

                                      `sort_order`   INT NOT NULL DEFAULT 1,
                                      `caption`      TEXT NULL,

                                      `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                      `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                      `revoked_at`   DATETIME NULL,

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

/* [Table 10] card_donation_group - 축의금/계좌 그룹(카드별 다수 가능) */
CREATE TABLE `card_donation_group` (
                                       `id`           BINARY(16) NOT NULL,
                                       `card_id`      BINARY(16) NOT NULL,

                                       `sort_order`   INT NOT NULL DEFAULT 1,
                                       `title`        TEXT NULL,
                                       `is_collapsed` TINYINT(1) NOT NULL DEFAULT 1,

                                       `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at`   DATETIME NULL,

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

/* [Table 11] card_donation_account - 축의금/계좌 항목(그룹 하위 리스트) */
CREATE TABLE `card_donation_account` (
                                         `id`             BINARY(16) NOT NULL,
                                         `group_id`       BINARY(16) NOT NULL,

                                         `sort_order`     INT NOT NULL DEFAULT 1,
                                         `account_holder` VARCHAR(120) NULL,
                                         `bank_name`      VARCHAR(120) NULL,
                                         `account_number` VARCHAR(120) NULL,

                                         `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                         `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                         `revoked_at`     DATETIME NULL,

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

/* [Table 12] card_notice_group - 안내사항 그룹(카드별 다수/정렬) */
CREATE TABLE `card_notice_group` (
                                     `id`          BINARY(16) NOT NULL,
                                     `card_id`     BINARY(16) NOT NULL,

                                     `group_type`  VARCHAR(16) NOT NULL DEFAULT 'grouped' COMMENT 'grouped/separate',
                                     `sort_order`  INT NOT NULL DEFAULT 1,
                                     `title`       TEXT NULL,

                                     `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at`  DATETIME NULL,

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

/* [Table 13] card_notice_item - 안내사항 항목(그룹 하위 리스트) */
CREATE TABLE `card_notice_item` (
                                    `id`           BINARY(16) NOT NULL,
                                    `group_id`     BINARY(16) NOT NULL,

                                    `sort_order`   INT NOT NULL DEFAULT 1,
                                    `title`        TEXT NULL,
                                    `content_html` LONGTEXT NULL,
                                    `is_sample`    TINYINT(1) NOT NULL DEFAULT 0,

                                    `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `revoked_at`   DATETIME NULL,

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

/* [Table 14] card_interview_item - Q&A 인터뷰 항목(정렬 가능한 리스트) */
CREATE TABLE `card_interview_item` (
                                       `id`          BINARY(16) NOT NULL,
                                       `card_id`     BINARY(16) NOT NULL,

                                       `sort_order`  INT NOT NULL DEFAULT 1,
                                       `question`    TEXT NULL,
                                       `answer`      TEXT NULL,

                                       `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at`  DATETIME NULL,

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


/* =========================================================
   PART 6) INTERACTION (대량/트래픽 많은 영역)
   ========================================================= */

/* [Table 15] card_guestbook_entry - 방명록 엔트리(대량/삭제/비공개 등) */
CREATE TABLE `card_guestbook_entry` (
                                        `id`                   BINARY(16) NOT NULL,
                                        `card_id`              BINARY(16) NOT NULL,

                                        `author_name`          VARCHAR(120) NOT NULL,
                                        `author_phone`         VARCHAR(40) NULL,
                                        `message_html`         LONGTEXT NOT NULL,

                                        `delete_password_hash` VARCHAR(255) NULL,
                                        `delete_password_salt` VARCHAR(255) NULL,

                                        `created_at`           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                        `updated_at`           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                        `revoked_at`           DATETIME NULL,

                                        PRIMARY KEY (`id`),
                                        KEY `idx_card_guestbook_entry_card_created` (`card_id`, `created_at`),
                                        KEY `idx_card_guestbook_entry_card_revoked` (`card_id`, `revoked_at`),
                                        KEY `idx_card_guestbook_entry_revoked_at` (`revoked_at`),

                                        CONSTRAINT `fk_card_guestbook_entry_card`
                                            FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* [Table 16] card_rsvp_response - RSVP 응답(대량/통계/다운로드 가능성) */
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
   PART 7) COMMERCE (WREATH & PAYMENT LOG)
   ========================================================= */

/* [Table 17] wreath_item - 화환 상품 카탈로그(가격/통화/활성화) */
CREATE TABLE `wreath_item` (
                               `id`              BINARY(16) NOT NULL,
                               `name`            VARCHAR(200) NOT NULL,
                               `description`     TEXT NULL,
                               `image_media_id`  BINARY(16) NULL,

    /* Money: Minor unit (정수) */
                               `base_price_minor` BIGINT NOT NULL DEFAULT 0,
                               `currency`        CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',
                               `is_active`       TINYINT(1) NOT NULL DEFAULT 1,

                               `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`      DATETIME NULL,

                               CONSTRAINT `chk_wreath_item_base_price_minor`
                                   CHECK (`base_price_minor` >= 0),
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

/* [Table 18] card_wreath_order - 카드별 화환 주문(결제 상태/표시 여부 포함) */
CREATE TABLE `card_wreath_order` (
                                     `id`              BINARY(16) NOT NULL,
                                     `card_id`         BINARY(16) NOT NULL,
                                     `wreath_item_id`  BINARY(16) NULL,

                                     `buyer_name`      VARCHAR(120) NOT NULL,
                                     `buyer_phone`     VARCHAR(40) NULL,
                                     `message`         TEXT NULL,
                                     `display_on_card` TINYINT(1) NOT NULL DEFAULT 1,

    /* Money: Minor unit (정수) */
                                     `price_paid_minor` BIGINT NULL,
                                     `currency`         CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',

                                     `payment_status`   VARCHAR(16) NOT NULL DEFAULT 'pending' COMMENT 'pending/paid/failed/refunded/cancelled',
                                     `payment_ref`      VARCHAR(200) NULL COMMENT 'PG사 Order/Payment ID',

                                     `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at`      DATETIME NULL,

                                     CONSTRAINT `chk_card_wreath_order_currency`
                                         CHECK (`currency` IN ('KRW','USD','VND')),
                                     CONSTRAINT `chk_card_wreath_order_payment_status`
                                         CHECK (`payment_status` IN ('pending','paid','failed','refunded','cancelled')),
                                     CONSTRAINT `chk_card_wreath_order_price_paid_minor`
                                         CHECK (`price_paid_minor` IS NULL OR `price_paid_minor` >= 0),

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

/* [Table 19] payment_event_log - 결제 이벤트 로그(시도/성공/실패/웹훅/환불 등 디버깅/감사 목적) */
CREATE TABLE `payment_event_log` (
                                     `id`          BINARY(16) NOT NULL,
                                     `order_id`    BINARY(16) NOT NULL,

                                     `event_type`  VARCHAR(32) NOT NULL COMMENT 'attempt/success/fail/webhook/refund/cancel',
                                     `provider`    VARCHAR(32) NULL COMMENT 'PG사/결제수단 식별자',
                                     `raw_payload` LONGTEXT NULL CHECK (JSON_VALID(`raw_payload`)) COMMENT 'PG 응답 원문(JSON)',

                                     `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

                                     PRIMARY KEY (`id`),
                                     KEY `idx_payment_event_log_order` (`order_id`),
                                     KEY `idx_payment_event_log_created_at` (`created_at`),

                                     CONSTRAINT `fk_payment_event_log_order`
                                         FOREIGN KEY (`order_id`) REFERENCES `card_wreath_order` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 8) SNAP (Google Drive Upload List)
   ========================================================= */

/* [Table 20] card_snap_upload - Snap 업로드 기록(대량/추적/삭제) */
CREATE TABLE `card_snap_upload` (
                                    `id`               BINARY(16) NOT NULL,
                                    `card_id`          BINARY(16) NOT NULL,

                                    `uploader_name`    VARCHAR(120) NULL,
                                    `uploader_phone`   VARCHAR(40) NULL,

                                    `provider_file_id` VARCHAR(200) NULL COMMENT 'Google Drive fileId',
                                    `provider_web_url` TEXT NULL,
                                    `file_name`        VARCHAR(255) NULL,
                                    `mime_type`        VARCHAR(128) NULL,
                                    `bytes`            BIGINT NULL,

                                    `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `revoked_at`       DATETIME NULL,

                                    PRIMARY KEY (`id`),
                                    KEY `idx_card_snap_upload_card_created` (`card_id`, `created_at`),
                                    KEY `idx_card_snap_upload_card_revoked` (`card_id`, `revoked_at`),
                                    KEY `idx_card_snap_upload_file_id` (`provider_file_id`),
                                    KEY `idx_card_snap_upload_revoked_at` (`revoked_at`),

                                    CONSTRAINT `fk_card_snap_upload_card`
                                        FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                            ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
