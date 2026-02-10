/* =========================================================
   PART 1) DATABASE
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
   PART 2) USER & AUTH (Google / Facebook / Zalo)
   ========================================================= */

/* [P2-T01] user_account: 내부 사용자 프로필(서비스 기준 사용자) */
CREATE TABLE `user_account` (
                                `id`             BINARY(16) NOT NULL,

                                `email`          VARCHAR(255) NULL,
                                `display_name`   VARCHAR(120) NULL,
                                `locale`         VARCHAR(10)  NOT NULL DEFAULT 'vi',
                                `timezone`       VARCHAR(64)  NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',

                                `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                `revoked_at`     DATETIME NULL,

                                PRIMARY KEY (`id`),
                                UNIQUE KEY `uq_user_account_email` (`email`),
                                KEY `idx_user_account_revoked_at` (`revoked_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P2-T02] user_identity: 소셜 계정(외부 provider)과 내부 user_account 연결 */
CREATE TABLE `user_identity` (
                                 `id`               BINARY(16) NOT NULL,
                                 `user_id`          BINARY(16) NOT NULL,

                                 `provider`         VARCHAR(16) NOT NULL COMMENT 'GOOGLE/FACEBOOK/ZALO',
                                 `provider_user_id` VARCHAR(191) NOT NULL COMMENT 'Google sub / Facebook id / Zalo id',
                                 `provider_email`   VARCHAR(255) NULL,
                                 `provider_name`    VARCHAR(200) NULL,
                                 `provider_picture_url` TEXT NULL,

                                 `raw_profile_json` LONGTEXT NULL COMMENT '원본 응답(JSON) 저장(디버깅/추적용, 필요 시만 사용)',

                                 `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                 `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                 `revoked_at`       DATETIME NULL,

                                 CONSTRAINT `chk_user_identity_provider`
                                     CHECK (`provider` IN ('GOOGLE','FACEBOOK','ZALO')),

                                 PRIMARY KEY (`id`),
                                 UNIQUE KEY `uq_user_identity_provider_uid` (`provider`, `provider_user_id`),
                                 KEY `idx_user_identity_user` (`user_id`),
                                 KEY `idx_user_identity_revoked_at` (`revoked_at`),

                                 CONSTRAINT `fk_user_identity_user`
                                     FOREIGN KEY (`user_id`) REFERENCES `user_account` (`id`)
                                         ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/*
  [P2-T03] user_oauth_token: (선택) 장기 접근이 필요한 경우에만 토큰 저장
  - 로그인만이면 보통 저장하지 않습니다(JWT/세션으로 처리).
  - Snap(Google Drive) 같은 기능이 "지속 접근"을 요구할 때만 사용하세요.
*/
CREATE TABLE `user_oauth_token` (
                                    `id`                BINARY(16) NOT NULL,
                                    `identity_id`       BINARY(16) NOT NULL,

                                    `access_token_enc`  TEXT NULL COMMENT 'App 레벨 암호화 필수',
                                    `refresh_token_enc` TEXT NULL COMMENT 'App 레벨 암호화 필수',
                                    `token_expires_at`  DATETIME NULL,
                                    `scopes`            TEXT NULL,

                                    `created_at`        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updated_at`        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `revoked_at`        DATETIME NULL,

                                    PRIMARY KEY (`id`),
                                    UNIQUE KEY `uq_user_oauth_token_identity` (`identity_id`),
                                    KEY `idx_user_oauth_token_revoked_at` (`revoked_at`),

                                    CONSTRAINT `fk_user_oauth_token_identity`
                                        FOREIGN KEY (`identity_id`) REFERENCES `user_identity` (`id`)
                                            ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 3) MEDIA (AWS S3 최적화)
   ========================================================= */

/* [P3-T01] media_asset: 이미지/비디오/오디오 등 미디어 메타 + S3 식별자 */
CREATE TABLE `media_asset` (
                               `id`              BINARY(16) NOT NULL,
                               `owner_user_id`   BINARY(16) NULL,

                               `storage_provider` VARCHAR(16) NOT NULL DEFAULT 'S3' COMMENT 'S3/EXTERNAL',
                               `bucket`          VARCHAR(64) NULL COMMENT 'S3 Bucket Name',
                               `object_key`      VARCHAR(512) NULL COMMENT 'S3 Object Key (File Path)',
                               `url`             TEXT NULL COMMENT 'CloudFront/CDN URL (캐시/표시용)',

                               `kind`            VARCHAR(16) NOT NULL COMMENT 'image/video/audio/thumbnail/document',
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
                                   CHECK (`kind` IN ('image','video','audio','thumbnail','document')),

                               PRIMARY KEY (`id`),
                               KEY `idx_media_asset_owner` (`owner_user_id`),
                               KEY `idx_media_asset_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_media_asset_owner`
                                   FOREIGN KEY (`owner_user_id`) REFERENCES `user_account` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 4) TEMPLATE
   ========================================================= */

/* [P4-T01] design_template: 템플릿 카탈로그(기본 설정 JSON 포함) */
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
                                   KEY `idx_design_template_active` (`is_active`),
                                   KEY `idx_design_template_revoked_at` (`revoked_at`),

                                   CONSTRAINT `fk_design_template_preview_media`
                                       FOREIGN KEY (`preview_media_id`) REFERENCES `media_asset` (`id`)
                                           ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 5) CARD (CORE) - 1:1 설정 최적화(대부분 JSON 통합)
   ========================================================= */

/*
  [P5-T01] card: 카드 핵심 + 조회/필터링용 컬럼 + 통합 설정 JSON
  - 1:1 성격의 설정(커버 레이아웃/오프닝/인사말/장소/갤러리 설정/비디오/섹션순서/RSVP 설정/방명록 설정/공지 설정/Snap 설정/화환 설정 등)은 config_json로 통합
  - 다만 FK 무결성이 중요한 미디어/트랙 참조는 JOIN 제거 + FK 유지 위해 card 컬럼으로 흡수:
    * cover_media_id
    * mid_photo_media_id
    * bgm_track_id (+ custom url)
*/
CREATE TABLE `card` (
                        `id`              BINARY(16) NOT NULL,
                        `owner_user_id`   BINARY(16) NOT NULL,

                        `kind`            VARCHAR(32) NOT NULL DEFAULT 'invitation' COMMENT 'invitation/wedding_video/thankyou_card',
                        `status`          VARCHAR(16) NOT NULL DEFAULT 'draft' COMMENT 'draft/published/archived',
                        `template_id`     BINARY(16) NULL,

                        `slug`            VARCHAR(120) NOT NULL COMMENT 'share url slug (unique)',
                        `share_token`     VARCHAR(128) NOT NULL COMMENT 'share token (unique)',

    /* 조회/정렬/필터링에 쓰이는 핵심 컬럼만 분리 */
                        `title`           VARCHAR(255) NOT NULL DEFAULT 'We are getting married',
                        `event_at`        DATETIME NULL COMMENT '검색/정렬용 예식 일시(표시는 config_json로 세밀제어 가능)',
                        `area_code`       VARCHAR(50) NULL COMMENT 'Hanoi/HCMC/Seoul 등 지역 필터링',
                        `currency`        CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',
                        `published_at`    DATETIME NULL,

    /* FK 무결성 유지 + JOIN 제거용 핵심 참조 */
                        `cover_media_id`      BINARY(16) NULL COMMENT '메인 커버 이미지(옵션)',
                        `mid_photo_media_id`  BINARY(16) NULL COMMENT '중간 사진(옵션)',

                        `bgm_track_id`        BINARY(16) NULL COMMENT 'BGM 트랙(옵션)',
                        `bgm_custom_audio_url` TEXT NULL COMMENT '커스텀 BGM URL(옵션)',
                        `bgm_autoplay`        TINYINT(1) NOT NULL DEFAULT 0,

    /* 통합 설정 JSON */
                        `config_json`     LONGTEXT NULL CHECK (JSON_VALID(`config_json`)),

    /*
      config_json 예시(중요: 여기로 card_video, 각종 1:1 설정 흡수)
      {
        "section_order": ["cover","greeting","gallery","location","rsvp","guestbook"],
        "opening_animation": { "enabled": true, "variant": "variant_1", "overlay_opacity": 0.5 },
        "cover": { "layout_variant": "fill", "show_border_line": false, "main_phrase_effect": "wave" },
        "greeting": { "title": "...", "content_html": "...", "show_names_under": true },
        "event_datetime": { "event_date": "2026-05-01", "event_time": "13:00", "timezone": "Asia/Ho_Chi_Minh" },
        "venue": { "venue_name": "...", "address_line1": "...", "lat": 10.123, "lng": 106.123, "map_provider": "google_maps" },
        "gallery_setting": { "gallery_type": "swipe", "open_popup_on_tap": true },
        "video": { "title": "...", "youtube_url": "...", "aspect_ratio": "16:9" },
        "mid_photo": { "effect": "fog" },
        "donation_setting": { "enabled": true, "display_type": "accordion" },
        "guestbook_setting": { "enabled": true, "design_type": "postit" },
        "rsvp_setting": { "enabled": true, "include_bus": false },
        "snap_setting": { "enabled": true, "drive_folder_id": "..." },
        "wreath_setting": { "enabled": true, "display_mode": "floating_menu" }
      }
    */

                        `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                        `revoked_at`      DATETIME NULL,

                        CONSTRAINT `chk_card_kind`
                            CHECK (`kind` IN ('invitation','wedding_video','thankyou_card')),
                        CONSTRAINT `chk_card_status`
                            CHECK (`status` IN ('draft','published','archived')),
                        CONSTRAINT `chk_card_currency`
                            CHECK (`currency` IN ('KRW','USD','VND')),
                        CONSTRAINT `chk_card_bgm_source`
                            CHECK (
                                (`bgm_track_id` IS NOT NULL AND `bgm_custom_audio_url` IS NULL)
                                    OR (`bgm_track_id` IS NULL AND `bgm_custom_audio_url` IS NOT NULL)
                                    OR (`bgm_track_id` IS NULL AND `bgm_custom_audio_url` IS NULL)
                                ),

                        PRIMARY KEY (`id`),
                        UNIQUE KEY `uq_card_slug` (`slug`),
                        UNIQUE KEY `uq_card_share_token` (`share_token`),
                        KEY `idx_card_owner` (`owner_user_id`),
                        KEY `idx_card_event_at` (`event_at`),
                        KEY `idx_card_status` (`status`),
                        KEY `idx_card_revoked_at` (`revoked_at`),

                        CONSTRAINT `fk_card_owner`
                            FOREIGN KEY (`owner_user_id`) REFERENCES `user_account` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT,
                        CONSTRAINT `fk_card_template`
                            FOREIGN KEY (`template_id`) REFERENCES `design_template` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT,

                        CONSTRAINT `fk_card_cover_media`
                            FOREIGN KEY (`cover_media_id`) REFERENCES `media_asset` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT,
                        CONSTRAINT `fk_card_mid_photo_media`
                            FOREIGN KEY (`mid_photo_media_id`) REFERENCES `media_asset` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT,
                        CONSTRAINT `fk_card_bgm_track`
                            FOREIGN KEY (`bgm_track_id`) REFERENCES `music_track` (`id`)
                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 6) CARD LIST DATA (1:N 관계는 테이블 유지)
   ========================================================= */

/* [P6-T01] card_person: 신랑/신부/부모 등 인물 정보(카드당 역할별 1개) */
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
                               KEY `idx_card_person_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_card_person_card`
                                   FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P6-T02] card_share_thumbnail: 공유 썸네일(플랫폼별 여러 개 가능) */
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
                                        KEY `idx_card_share_thumbnail_revoked_at` (`revoked_at`),

                                        CONSTRAINT `fk_card_share_thumbnail_card`
                                            FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT,
                                        CONSTRAINT `fk_card_share_thumbnail_media`
                                            FOREIGN KEY (`image_media_id`) REFERENCES `media_asset` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P6-T03] card_transport_item: 교통/오시는 길 안내 항목(여러 개) */
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
                                       KEY `idx_card_transport_item_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_transport_item_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P6-T04] card_gallery_photo: 갤러리 사진(여러 개) */
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
                                      KEY `idx_card_gallery_photo_revoked_at` (`revoked_at`),

                                      CONSTRAINT `fk_card_gallery_photo_card`
                                          FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                              ON UPDATE RESTRICT ON DELETE RESTRICT,
                                      CONSTRAINT `fk_card_gallery_photo_media`
                                          FOREIGN KEY (`media_id`) REFERENCES `media_asset` (`id`)
                                              ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 7) MUSIC CATALOG (공용)
   ========================================================= */

/* [P7-T01] music_track: 배경음악 카탈로그(여러 카드에서 참조) */
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
                               KEY `idx_music_track_active` (`is_active`),
                               KEY `idx_music_track_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_music_track_audio_media`
                                   FOREIGN KEY (`audio_media_id`) REFERENCES `media_asset` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 8) INTERACTION (Guestbook / RSVP)
   ========================================================= */

/* [P8-T01] card_guestbook_entry: 방명록 엔트리(여러 개) */
CREATE TABLE `card_guestbook_entry` (
                                        `id`                  BINARY(16) NOT NULL,
                                        `card_id`             BINARY(16) NOT NULL,

                                        `author_name`         VARCHAR(120) NOT NULL,
                                        `author_phone`        VARCHAR(40) NULL,
                                        `message_html`        LONGTEXT NOT NULL,

                                        `delete_password_hash` VARCHAR(255) NULL,
                                        `delete_password_salt` VARCHAR(255) NULL,

                                        `created_at`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                        `updated_at`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                        `revoked_at`          DATETIME NULL,

                                        PRIMARY KEY (`id`),
                                        KEY `idx_card_guestbook_entry_card_created` (`card_id`, `created_at`),
                                        KEY `idx_card_guestbook_entry_revoked_at` (`revoked_at`),

                                        CONSTRAINT `fk_card_guestbook_entry_card`
                                            FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                                ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P8-T02] card_rsvp_response: RSVP 응답(여러 개) */
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
                                      KEY `idx_card_rsvp_response_revoked_at` (`revoked_at`),

                                      CONSTRAINT `fk_card_rsvp_response_card`
                                          FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                              ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 9) DONATION (그룹/계좌는 리스트이므로 테이블 유지)
   ========================================================= */

/* [P9-T01] card_donation_group: 축의금/계좌 그룹(예: 신랑측/신부측) */
CREATE TABLE `card_donation_group` (
                                       `id`          BINARY(16) NOT NULL,
                                       `card_id`     BINARY(16) NOT NULL,

                                       `sort_order`  INT NOT NULL DEFAULT 1,
                                       `title`       TEXT NULL,
                                       `is_collapsed` TINYINT(1) NOT NULL DEFAULT 1,

                                       `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                       `revoked_at`  DATETIME NULL,

                                       CONSTRAINT `chk_card_donation_group_sort`
                                           CHECK (`sort_order` >= 1),

                                       PRIMARY KEY (`id`),
                                       UNIQUE KEY `uq_card_donation_group_sort` (`card_id`, `sort_order`),
                                       KEY `idx_card_donation_group_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_donation_group_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P9-T02] card_donation_account: 그룹 내 계좌 항목 */
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
                                         KEY `idx_card_donation_account_revoked_at` (`revoked_at`),

                                         CONSTRAINT `fk_card_donation_account_group`
                                             FOREIGN KEY (`group_id`) REFERENCES `card_donation_group` (`id`)
                                                 ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 10) INTERVIEW / NOTICE (리스트형 유지)
   ========================================================= */

/* [P10-T01] card_interview_item: 인터뷰 Q&A 항목(여러 개) */
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
                                       KEY `idx_card_interview_item_revoked_at` (`revoked_at`),

                                       CONSTRAINT `fk_card_interview_item_card`
                                           FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                               ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P10-T02] card_notice_group: 공지 그룹(여러 개) */
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
                                     KEY `idx_card_notice_group_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_card_notice_group_card`
                                         FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P10-T03] card_notice_item: 공지 그룹 내 아이템(여러 개) */
CREATE TABLE `card_notice_item` (
                                    `id`          BINARY(16) NOT NULL,
                                    `group_id`    BINARY(16) NOT NULL,

                                    `sort_order`  INT NOT NULL DEFAULT 1,
                                    `title`       TEXT NULL,
                                    `content_html` LONGTEXT NULL,
                                    `is_sample`   TINYINT(1) NOT NULL DEFAULT 0,

                                    `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `revoked_at`  DATETIME NULL,

                                    CONSTRAINT `chk_card_notice_item_sort`
                                        CHECK (`sort_order` >= 1),

                                    PRIMARY KEY (`id`),
                                    UNIQUE KEY `uq_card_notice_item_sort` (`group_id`, `sort_order`),
                                    KEY `idx_card_notice_item_revoked_at` (`revoked_at`),

                                    CONSTRAINT `fk_card_notice_item_group`
                                        FOREIGN KEY (`group_id`) REFERENCES `card_notice_group` (`id`)
                                            ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 11) WREATH & PAYMENT (금액 minor unit + 결제 이벤트 로그)
   ========================================================= */

/* [P11-T01] wreath_item: 화환 상품 카탈로그(금액은 minor unit BIGINT) */
CREATE TABLE `wreath_item` (
                               `id`               BINARY(16) NOT NULL,
                               `name`             VARCHAR(200) NOT NULL,
                               `description`      TEXT NULL,
                               `image_media_id`   BINARY(16) NULL,

                               `base_price_minor` BIGINT NOT NULL DEFAULT 0,
                               `currency`         CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',
                               `is_active`        TINYINT(1) NOT NULL DEFAULT 1,

                               `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                               `revoked_at`       DATETIME NULL,

                               CONSTRAINT `chk_wreath_item_currency`
                                   CHECK (`currency` IN ('KRW','USD','VND')),
                               CONSTRAINT `chk_wreath_item_base_price_minor`
                                   CHECK (`base_price_minor` >= 0),

                               PRIMARY KEY (`id`),
                               KEY `idx_wreath_item_active` (`is_active`),
                               KEY `idx_wreath_item_revoked_at` (`revoked_at`),

                               CONSTRAINT `fk_wreath_item_media`
                                   FOREIGN KEY (`image_media_id`) REFERENCES `media_asset` (`id`)
                                       ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P11-T02] card_wreath_order: 카드별 화환 주문(결제 상태 포함) */
CREATE TABLE `card_wreath_order` (
                                     `id`               BINARY(16) NOT NULL,
                                     `card_id`          BINARY(16) NOT NULL,
                                     `wreath_item_id`   BINARY(16) NULL,

                                     `buyer_name`       VARCHAR(120) NOT NULL,
                                     `buyer_phone`      VARCHAR(40) NULL,
                                     `message`          TEXT NULL,
                                     `display_on_card`  TINYINT(1) NOT NULL DEFAULT 1,

                                     `price_paid_minor` BIGINT NULL,
                                     `currency`         CHAR(3) NOT NULL DEFAULT 'VND' COMMENT 'KRW/USD/VND',

                                     `payment_status`   VARCHAR(16) NOT NULL DEFAULT 'pending' COMMENT 'pending/paid/failed/refunded/cancelled',
                                     `payment_ref`      VARCHAR(200) NULL COMMENT 'PG사 Order ID',

                                     `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                     `revoked_at`       DATETIME NULL,

                                     CONSTRAINT `chk_card_wreath_order_currency`
                                         CHECK (`currency` IN ('KRW','USD','VND')),
                                     CONSTRAINT `chk_card_wreath_order_payment_status`
                                         CHECK (`payment_status` IN ('pending','paid','failed','refunded','cancelled')),
                                     CONSTRAINT `chk_card_wreath_order_price_paid_minor`
                                         CHECK (`price_paid_minor` IS NULL OR `price_paid_minor` >= 0),

                                     PRIMARY KEY (`id`),
                                     KEY `idx_card_wreath_order_card_created` (`card_id`, `created_at`),
                                     KEY `idx_card_wreath_order_revoked_at` (`revoked_at`),

                                     CONSTRAINT `fk_card_wreath_order_card`
                                         FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT,
                                     CONSTRAINT `fk_card_wreath_order_item`
                                         FOREIGN KEY (`wreath_item_id`) REFERENCES `wreath_item` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* [P11-T03] payment_event_log: 결제 이벤트/웹훅/실패/환불 로그(디버깅용) */
CREATE TABLE `payment_event_log` (
                                     `id`          BINARY(16) NOT NULL,
                                     `order_id`    BINARY(16) NOT NULL,

                                     `event_type`  VARCHAR(32) NOT NULL COMMENT 'attempt/success/fail/webhook/refund',
                                     `provider`    VARCHAR(32) NULL,
                                     `raw_payload` LONGTEXT NULL CHECK (JSON_VALID(`raw_payload`)),

                                     `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

                                     PRIMARY KEY (`id`),
                                     KEY `idx_payment_event_log_order` (`order_id`),

                                     CONSTRAINT `fk_payment_event_log_order`
                                         FOREIGN KEY (`order_id`) REFERENCES `card_wreath_order` (`id`)
                                             ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* =========================================================
   PART 12) SNAP (Google Drive 업로드 목록은 리스트이므로 유지)
   ========================================================= */

/* [P12-T01] card_snap_upload: Snap 업로드 기록(여러 개) */
CREATE TABLE `card_snap_upload` (
                                    `id`              BINARY(16) NOT NULL,
                                    `card_id`         BINARY(16) NOT NULL,

                                    `uploader_name`   VARCHAR(120) NULL,
                                    `uploader_phone`  VARCHAR(40) NULL,

                                    `provider_file_id` VARCHAR(200) NULL COMMENT 'Google Drive fileId',
                                    `provider_web_url` TEXT NULL,
                                    `file_name`       VARCHAR(255) NULL,
                                    `mime_type`       VARCHAR(128) NULL,
                                    `bytes`           BIGINT NULL,

                                    `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `revoked_at`      DATETIME NULL,

                                    PRIMARY KEY (`id`),
                                    KEY `idx_card_snap_upload_card_created` (`card_id`, `created_at`),
                                    KEY `idx_card_snap_upload_revoked_at` (`revoked_at`),

                                    CONSTRAINT `fk_card_snap_upload_card`
                                        FOREIGN KEY (`card_id`) REFERENCES `card` (`id`)
                                            ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
