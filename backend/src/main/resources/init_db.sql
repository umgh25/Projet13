-- ============================================================
-- YOUR CAR YOUR WAY — Script d'initialisation de la base de données
-- Approche : Domain-Driven Design (DDD)
-- SGBD      : PostgreSQL 15+
-- Normes    : 3ème forme normale (3NF)
-- ============================================================

-- Extension pour UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- DOMAINE : UTILISATEUR (User)
-- ============================================================

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    birth_date    DATE         NOT NULL,
    address_line  VARCHAR(255),
    city          VARCHAR(100),
    country       VARCHAR(100),
    locale        VARCHAR(10)  NOT NULL DEFAULT 'en',
    is_verified   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Tokens de vérification / réinitialisation
CREATE TABLE user_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      VARCHAR(512) NOT NULL UNIQUE,
    type       VARCHAR(50)  NOT NULL, -- 'email_verification' | 'password_reset'
    expires_at TIMESTAMPTZ  NOT NULL,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Sessions utilisateur
CREATE TABLE user_sessions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DOMAINE : AGENCE (Agency)
-- ============================================================

CREATE TABLE agencies (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(255) NOT NULL,
    address    VARCHAR(255) NOT NULL,
    city       VARCHAR(100) NOT NULL,
    country    VARCHAR(100) NOT NULL,
    latitude   DECIMAL(9,6),
    longitude  DECIMAL(9,6),
    phone      VARCHAR(30),
    email      VARCHAR(255),
    is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DOMAINE : VEHICULE (Vehicle / ACRISS)
-- ============================================================

-- Catégories ACRISS (norme internationale)
CREATE TABLE vehicle_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    acriss_code CHAR(4)      NOT NULL UNIQUE, -- ex: CCAR, SDAR
    label       VARCHAR(100) NOT NULL,         -- ex: Economy, Standard SUV
    description TEXT
);

CREATE TABLE vehicles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id   UUID         NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    category_id UUID         NOT NULL REFERENCES vehicle_categories(id),
    brand       VARCHAR(100) NOT NULL,
    model       VARCHAR(100) NOT NULL,
    plate       VARCHAR(20)  NOT NULL UNIQUE,
    year        SMALLINT     NOT NULL,
    is_available BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DOMAINE : OFFRE DE LOCATION (Rental Offer)
-- ============================================================

CREATE TABLE rental_offers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    departure_agency_id UUID           NOT NULL REFERENCES agencies(id),
    return_agency_id    UUID           NOT NULL REFERENCES agencies(id),
    vehicle_category_id UUID           NOT NULL REFERENCES vehicle_categories(id),
    departure_at        TIMESTAMPTZ    NOT NULL,
    return_at           TIMESTAMPTZ    NOT NULL,
    daily_rate          DECIMAL(10,2)  NOT NULL,
    currency            CHAR(3)        NOT NULL DEFAULT 'EUR',
    is_active           BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_dates CHECK (return_at > departure_at)
);

-- ============================================================
-- DOMAINE : RÉSERVATION (Booking)
-- ============================================================

CREATE TYPE booking_status AS ENUM (
    'pending',
    'confirmed',
    'modified',
    'cancelled',
    'completed'
);

CREATE TABLE bookings (
    id              UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID           NOT NULL REFERENCES users(id),
    offer_id        UUID           NOT NULL REFERENCES rental_offers(id),
    vehicle_id      UUID           REFERENCES vehicles(id),
    status          booking_status NOT NULL DEFAULT 'pending',
    total_amount    DECIMAL(10,2)  NOT NULL,
    currency        CHAR(3)        NOT NULL DEFAULT 'EUR',
    -- Snapshot des infos client au moment de la réservation
    driver_first_name VARCHAR(100) NOT NULL,
    driver_last_name  VARCHAR(100) NOT NULL,
    driver_birth_date DATE         NOT NULL,
    driver_address    VARCHAR(255),
    -- Paiement
    payment_status    VARCHAR(50)  NOT NULL DEFAULT 'pending', -- pending | paid | refunded | partial_refund
    payment_provider  VARCHAR(50)  DEFAULT 'stripe',
    payment_ref       VARCHAR(255),
    -- Remboursement
    refund_amount     DECIMAL(10,2),
    refunded_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Historique des modifications de réservation
CREATE TABLE booking_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id  UUID        NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    old_status  booking_status,
    new_status  booking_status NOT NULL,
    changed_by  UUID        REFERENCES users(id),
    reason      TEXT,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DOMAINE : NOTIFICATIONS (Notification)
-- ============================================================

CREATE TYPE notification_type AS ENUM (
    'email_verification',
    'password_reset',
    'booking_confirmation',
    'booking_modification',
    'booking_cancellation',
    'booking_reminder',
    'support_reply'
);

CREATE TABLE notifications (
    id          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID              NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        notification_type NOT NULL,
    subject     VARCHAR(255)      NOT NULL,
    body        TEXT              NOT NULL,
    sent_at     TIMESTAMPTZ,
    is_sent     BOOLEAN           NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DOMAINE : SERVICE CLIENT / CHAT (Support)
-- ============================================================

CREATE TYPE message_channel AS ENUM ('chat', 'async');
CREATE TYPE conversation_status AS ENUM ('open', 'closed', 'pending');

CREATE TABLE support_conversations (
    id          UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID                NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    booking_id  UUID                REFERENCES bookings(id),
    channel     message_channel     NOT NULL DEFAULT 'async',
    status      conversation_status NOT NULL DEFAULT 'open',
    subject     VARCHAR(255),
    opened_at   TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    closed_at   TIMESTAMPTZ,
    updated_at  TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE TABLE support_messages (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID        NOT NULL REFERENCES support_conversations(id) ON DELETE CASCADE,
    sender_id       UUID        NOT NULL REFERENCES users(id),
    sender_role     VARCHAR(20) NOT NULL DEFAULT 'client', -- 'client' | 'agent'
    content         TEXT        NOT NULL,
    sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_read         BOOLEAN     NOT NULL DEFAULT FALSE
);

-- ============================================================
-- INDEX — Performance
-- ============================================================

CREATE INDEX idx_users_email            ON users(email);
CREATE INDEX idx_user_tokens_user       ON user_tokens(user_id);
CREATE INDEX idx_user_sessions_user     ON user_sessions(user_id);
CREATE INDEX idx_vehicles_agency        ON vehicles(agency_id);
CREATE INDEX idx_vehicles_category      ON vehicles(vehicle_category_id);
CREATE INDEX idx_offers_departure       ON rental_offers(departure_agency_id);
CREATE INDEX idx_offers_return          ON rental_offers(return_agency_id);
CREATE INDEX idx_offers_category        ON rental_offers(vehicle_category_id);
CREATE INDEX idx_offers_dates           ON rental_offers(departure_at, return_at);
CREATE INDEX idx_bookings_user          ON bookings(user_id);
CREATE INDEX idx_bookings_offer         ON bookings(offer_id);
CREATE INDEX idx_bookings_status        ON bookings(status);
CREATE INDEX idx_booking_history_booking ON booking_history(booking_id);
CREATE INDEX idx_notifications_user     ON notifications(user_id);
CREATE INDEX idx_conversations_user     ON support_conversations(user_id);
CREATE INDEX idx_messages_conversation  ON support_messages(conversation_id);

-- ============================================================
-- DONNÉES DE RÉFÉRENCE — Catégories ACRISS (exemples)
-- ============================================================

INSERT INTO vehicle_categories (acriss_code, label, description) VALUES
    ('MBMN', 'Mini',         'Mini / City car, manuelle'),
    ('ECMN', 'Economy',      'Économique, climatisation, manuelle'),
    ('CCMN', 'Compact',      'Compacte, climatisation, manuelle'),
    ('ICAR', 'Intermediate', 'Intermédiaire, automatique'),
    ('SCAR', 'Standard',     'Standard, automatique'),
    ('FCAR', 'Fullsize',     'Grande berline, automatique'),
    ('PFAR', 'Premium',      'Premium, 4 portes, automatique'),
    ('LDAR', 'Luxury',       'Luxe, 4 portes, automatique'),
    ('IFAR', 'SUV Compact',  'SUV compact, automatique'),
    ('SFAR', 'SUV Standard', 'SUV standard, automatique'),
    ('FFAR', 'SUV Fullsize', 'Grand SUV, automatique'),
    ('MVAR', 'Minivan',      'Monospace, automatique'),
    ('XCAR', 'Spécial',      'Véhicule spécial / électrique');

-- ============================================================
-- FIN DU SCRIPT
-- ============================================================
