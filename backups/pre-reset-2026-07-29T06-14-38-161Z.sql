--
-- PostgreSQL database dump
--

\restrict vZqJpB1pvS149pFufT1nwfeP2gWCI6uD27u1epCemlWs9JSJ1CS4re8SlqZZvEQ

-- Dumped from database version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: isp_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.isp_status AS ENUM (
    'pending',
    'active',
    'suspended',
    'cancelled'
);


ALTER TYPE public.isp_status OWNER TO rumalink_user;

--
-- Name: notification_type; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.notification_type AS ENUM (
    'info',
    'warning',
    'success',
    'error'
);


ALTER TYPE public.notification_type OWNER TO rumalink_user;

--
-- Name: payment_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.payment_status AS ENUM (
    'pending',
    'paid',
    'failed',
    'refunded',
    'partial'
);


ALTER TYPE public.payment_status OWNER TO rumalink_user;

--
-- Name: plan_type; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.plan_type AS ENUM (
    'hotspot',
    'pppoe'
);


ALTER TYPE public.plan_type OWNER TO rumalink_user;

--
-- Name: session_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.session_status AS ENUM (
    'active',
    'closed',
    'expired'
);


ALTER TYPE public.session_status OWNER TO rumalink_user;

--
-- Name: transaction_type; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.transaction_type AS ENUM (
    'payment',
    'refund',
    'commission',
    'payout',
    'adjustment'
);


ALTER TYPE public.transaction_type OWNER TO rumalink_user;

--
-- Name: user_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.user_status AS ENUM (
    'active',
    'inactive',
    'suspended',
    'expired'
);


ALTER TYPE public.user_status OWNER TO rumalink_user;

--
-- Name: voucher_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.voucher_status AS ENUM (
    'unused',
    'active',
    'used',
    'expired'
);


ALTER TYPE public.voucher_status OWNER TO rumalink_user;

--
-- Name: _audit_radreply_del(); Type: FUNCTION; Schema: public; Owner: rumalink_user
--

CREATE FUNCTION public._audit_radreply_del() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.username = 'benard' THEN
    INSERT INTO _radreply_audit(username, attribute, pid, query)
    VALUES (OLD.username, OLD.attribute, pg_backend_pid(), current_query());
  END IF;
  RETURN OLD;
END;
$$;


ALTER FUNCTION public._audit_radreply_del() OWNER TO rumalink_user;

--
-- Name: _rl_set(text, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._rl_set(k text, v numeric) RETURNS void
    LANGUAGE sql
    AS $$
  INSERT INTO platform_settings (key, value, updated_at) VALUES (k, v, NOW())
  ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=NOW();
$$;


ALTER FUNCTION public._rl_set(k text, v numeric) OWNER TO postgres;

--
-- Name: rl_audit_radcheck_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rl_audit_radcheck_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO radcheck_delete_audit (username, app_name, client_addr, backend_pid, query_text)
  VALUES (OLD.username,
          COALESCE(current_setting('application_name', true),'?'),
          inet_client_addr(),
          pg_backend_pid(),
          (SELECT query FROM pg_stat_activity WHERE pid = pg_backend_pid()));
  RETURN OLD;
END;
$$;


ALTER FUNCTION public.rl_audit_radcheck_delete() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _mac_delete_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._mac_delete_log (
    id integer NOT NULL,
    deleted_username text,
    deleted_at timestamp with time zone DEFAULT now(),
    query text,
    app text
);


ALTER TABLE public._mac_delete_log OWNER TO postgres;

--
-- Name: _mac_delete_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public._mac_delete_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public._mac_delete_log_id_seq OWNER TO postgres;

--
-- Name: _mac_delete_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public._mac_delete_log_id_seq OWNED BY public._mac_delete_log.id;


--
-- Name: _radreply_audit; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public._radreply_audit (
    id integer NOT NULL,
    username text,
    attribute text,
    deleted_at timestamp with time zone DEFAULT now(),
    pid integer,
    query text
);


ALTER TABLE public._radreply_audit OWNER TO rumalink_user;

--
-- Name: _radreply_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public._radreply_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public._radreply_audit_id_seq OWNER TO rumalink_user;

--
-- Name: _radreply_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public._radreply_audit_id_seq OWNED BY public._radreply_audit.id;


--
-- Name: admins; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.admins (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    role character varying(50) DEFAULT 'superadmin'::character varying,
    is_active boolean DEFAULT true,
    last_login timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.admins OWNER TO rumalink_user;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    actor_type character varying(20) NOT NULL,
    actor_id uuid NOT NULL,
    action character varying(100) NOT NULL,
    resource_type character varying(100),
    resource_id uuid,
    changes jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.audit_logs OWNER TO rumalink_user;

--
-- Name: commissions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.commissions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    payment_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    rate numeric(5,4) NOT NULL,
    period_month integer,
    period_year integer,
    is_settled boolean DEFAULT false,
    settled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.commissions OWNER TO rumalink_user;

--
-- Name: email_provider_config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.email_provider_config (
    id integer NOT NULL,
    provider text DEFAULT 'resend'::text NOT NULL,
    smtp_host text,
    smtp_port integer DEFAULT 587,
    smtp_secure boolean DEFAULT false,
    smtp_user text,
    smtp_pass text,
    from_email text,
    from_name text DEFAULT 'RumaLink Enterprise'::text,
    is_active boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now(),
    logo_url text,
    logo_bg text
);


ALTER TABLE public.email_provider_config OWNER TO postgres;

--
-- Name: email_provider_config_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.email_provider_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.email_provider_config_id_seq OWNER TO postgres;

--
-- Name: email_provider_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.email_provider_config_id_seq OWNED BY public.email_provider_config.id;


--
-- Name: hotspot_bound_devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hotspot_bound_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    isp_id uuid NOT NULL,
    name text NOT NULL,
    mac_address text NOT NULL,
    buyer_phone text,
    active_voucher_id uuid,
    bound_ip text,
    package_id uuid,
    expires_at timestamp with time zone,
    is_bound boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    usage_base_in bigint DEFAULT 0,
    usage_base_out bigint DEFAULT 0,
    last_ctr_in bigint DEFAULT 0,
    last_ctr_out bigint DEFAULT 0
);


ALTER TABLE public.hotspot_bound_devices OWNER TO postgres;

--
-- Name: hotspot_packages; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.hotspot_packages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    nas_id uuid,
    name character varying(255) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    duration_hours integer,
    bandwidth_down_mbps integer,
    bandwidth_up_mbps integer,
    data_limit_mb integer,
    simultaneous_sessions integer DEFAULT 1,
    mikrotik_profile character varying(100),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.hotspot_packages OWNER TO rumalink_user;

--
-- Name: hotspot_sessions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.hotspot_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    voucher_id uuid,
    nas_id uuid,
    radius_session_id character varying(255),
    mac_address character varying(17),
    ip_address character varying(45),
    nas_ip character varying(45),
    bytes_downloaded bigint DEFAULT 0,
    bytes_uploaded bigint DEFAULT 0,
    session_time_seconds integer DEFAULT 0,
    status public.session_status DEFAULT 'active'::public.session_status,
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    terminate_cause character varying(100)
);


ALTER TABLE public.hotspot_sessions OWNER TO rumalink_user;

--
-- Name: hotspot_vouchers; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.hotspot_vouchers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    package_id uuid NOT NULL,
    nas_id uuid,
    code character varying(50) NOT NULL,
    batch_id uuid,
    status public.voucher_status DEFAULT 'unused'::public.voucher_status,
    used_by_mac character varying(17),
    used_by_ip character varying(45),
    used_at timestamp with time zone,
    expires_at timestamp with time zone,
    bytes_downloaded bigint DEFAULT 0,
    bytes_uploaded bigint DEFAULT 0,
    time_used_seconds integer DEFAULT 0,
    is_paid boolean DEFAULT false,
    amount_paid numeric(10,2),
    payment_method character varying(50),
    payment_reference text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    buyer_phone character varying(20),
    sms_sent boolean DEFAULT false,
    expiry_sms_sent boolean DEFAULT false,
    payment_id uuid,
    is_test boolean DEFAULT false,
    password text DEFAULT substr(translate(lower(encode(public.gen_random_bytes(8), 'hex'::text)), '01'::text, 'xy'::text), 1, 6),
    is_tv boolean DEFAULT false,
    tv_mac text,
    created_by_isp boolean DEFAULT false,
    import_batch text
);


ALTER TABLE public.hotspot_vouchers OWNER TO rumalink_user;

--
-- Name: intasend_withdrawals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.intasend_withdrawals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    isp_id uuid NOT NULL,
    method character varying(20) NOT NULL,
    destination jsonb NOT NULL,
    gross_amount numeric(12,2) NOT NULL,
    fee_amount numeric(12,2) NOT NULL,
    net_amount numeric(12,2) NOT NULL,
    below_threshold boolean DEFAULT false,
    status character varying(20) DEFAULT 'pending'::character varying,
    intasend_ref character varying(128),
    intasend_state character varying(40),
    failure_reason text,
    balance_before numeric(12,2),
    balance_after numeric(12,2),
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.intasend_withdrawals OWNER TO postgres;

--
-- Name: isp_captive_portal; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_captive_portal (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    template character varying(50) DEFAULT 'classic'::character varying,
    primary_color character varying(20) DEFAULT '#00d4aa'::character varying,
    secondary_color character varying(20) DEFAULT '#0d1530'::character varying,
    logo_url text,
    welcome_title character varying(255) DEFAULT 'Welcome! Connect to WiFi'::character varying,
    welcome_subtitle text DEFAULT 'Select a package below to get started'::text,
    bg_image_url text,
    show_logo boolean DEFAULT true,
    show_powered_by boolean DEFAULT true,
    custom_css text,
    updated_at timestamp with time zone DEFAULT now(),
    support_number character varying(255),
    support_label character varying(255),
    enable_tv_mode boolean DEFAULT false,
    notif_enabled boolean DEFAULT false,
    notif_title character varying(255),
    notif_message text,
    notif_severity character varying(20) DEFAULT 'info'::character varying,
    notif_start timestamp with time zone,
    notif_end timestamp with time zone,
    media_enabled boolean DEFAULT false,
    media_type character varying(20) DEFAULT 'carousel'::character varying,
    media_video_url text,
    media_images jsonb DEFAULT '[]'::jsonb,
    media_interval integer DEFAULT 4,
    media_fit character varying(10) DEFAULT 'contain'::character varying
);


ALTER TABLE public.isp_captive_portal OWNER TO rumalink_user;

--
-- Name: isp_payment_methods; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_payment_methods (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    method_type character varying(30) NOT NULL,
    label character varying(100),
    shortcode character varying(20),
    consumer_key text,
    consumer_secret text,
    passkey text,
    is_sandbox boolean DEFAULT false,
    use_admin_credentials boolean DEFAULT false,
    till_number character varying(20),
    paybill_number character varying(20),
    account_reference character varying(100),
    bank_name character varying(100),
    account_name character varying(100),
    account_number character varying(50),
    branch character varying(100),
    forward_to_type character varying(30),
    forward_to_number character varying(50),
    forward_to_name character varying(100),
    is_active boolean DEFAULT true,
    is_verified boolean DEFAULT false,
    is_default boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    provider character varying(32)
);


ALTER TABLE public.isp_payment_methods OWNER TO rumalink_user;

--
-- Name: isp_platform_invoices; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_platform_invoices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    period_month integer NOT NULL,
    period_year integer NOT NULL,
    pppoe_user_count integer DEFAULT 0,
    amount_per_user numeric(10,2) DEFAULT 32.00,
    total_amount numeric(10,2) NOT NULL,
    status public.payment_status DEFAULT 'pending'::public.payment_status,
    due_date date,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    invoice_number character varying(30),
    invoice_type character varying(30) DEFAULT 'pppoe_monthly'::character varying,
    payment_id uuid,
    hotspot_revenue numeric(12,2) DEFAULT 0,
    hotspot_fee numeric(12,2) DEFAULT 0,
    hotspot_rate numeric(6,4) DEFAULT 0.03,
    pppoe_fee numeric(12,2) DEFAULT 0,
    window_start timestamp with time zone,
    window_end timestamp with time zone,
    period_expires_at timestamp with time zone
);


ALTER TABLE public.isp_platform_invoices OWNER TO rumalink_user;

--
-- Name: isp_transactions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    type public.transaction_type NOT NULL,
    amount numeric(15,2) NOT NULL,
    balance_before numeric(15,2),
    balance_after numeric(15,2),
    description text,
    reference_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.isp_transactions OWNER TO rumalink_user;

--
-- Name: isps; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isps (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    company_name character varying(255) NOT NULL,
    owner_name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    phone character varying(20) NOT NULL,
    password_hash text NOT NULL,
    plan_type character varying(20) DEFAULT 'hotspot'::public.plan_type NOT NULL,
    status public.isp_status DEFAULT 'pending'::public.isp_status,
    county character varying(100),
    town character varying(100),
    address text,
    api_key uuid DEFAULT public.uuid_generate_v4(),
    api_secret text DEFAULT encode(public.gen_random_bytes(32), 'hex'::text),
    webhook_url text,
    wallet_balance numeric(15,2) DEFAULT 0.00,
    commission_rate numeric(5,4) DEFAULT 0.03,
    pppoe_rate_per_user numeric(10,2) DEFAULT 32.25,
    total_earned numeric(15,2) DEFAULT 0.00,
    total_commission_paid numeric(15,2) DEFAULT 0.00,
    sms_gateway character varying(50),
    sms_api_key text,
    sms_sender_id character varying(20),
    logo_url text,
    timezone character varying(50) DEFAULT 'Africa/Nairobi'::character varying,
    currency character varying(10) DEFAULT 'KES'::character varying,
    email_verified boolean DEFAULT false,
    email_verify_token text,
    password_reset_token text,
    password_reset_expires timestamp with time zone,
    trial_ends_at timestamp with time zone DEFAULT (now() + '30 days'::interval),
    last_login timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    sms_username character varying(100),
    sms_partner_id character varying(100),
    sms_api_secret text,
    support_number character varying(30),
    hotspot_counter integer DEFAULT 0,
    subscription_started_at timestamp with time zone,
    license_expires_at timestamp with time zone,
    billing_window_start timestamp with time zone,
    license_status character varying(20) DEFAULT 'trial'::character varying,
    billing_exempt boolean DEFAULT false,
    sms_balance numeric(12,4) DEFAULT 0 NOT NULL,
    phone_verified boolean DEFAULT false,
    phone_verified_at timestamp with time zone,
    email_verified_at timestamp with time zone
);


ALTER TABLE public.isps OWNER TO rumalink_user;

--
-- Name: mac_auth_cache; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.mac_auth_cache (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    mac_address character varying(17) NOT NULL,
    isp_id uuid,
    package_id uuid,
    authorized_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.mac_auth_cache OWNER TO rumalink_user;

--
-- Name: mpesa_configs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.mpesa_configs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid,
    shortcode character varying(20),
    consumer_key text,
    consumer_secret text,
    passkey text,
    callback_url text,
    is_sandbox boolean DEFAULT false,
    is_active boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_admin_config boolean DEFAULT false
);


ALTER TABLE public.mpesa_configs OWNER TO rumalink_user;

--
-- Name: mpesa_transactions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.mpesa_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    payment_id uuid,
    checkout_request_id character varying(255),
    merchant_request_id character varying(255),
    result_code integer,
    result_desc text,
    amount numeric(10,2),
    mpesa_receipt character varying(50),
    phone character varying(20),
    transaction_date timestamp with time zone,
    status character varying(50) DEFAULT 'pending'::character varying,
    raw_callback jsonb,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.mpesa_transactions OWNER TO rumalink_user;

--
-- Name: nas; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas (
    id integer NOT NULL,
    nasname text NOT NULL,
    shortname text NOT NULL,
    type text DEFAULT 'other'::text NOT NULL,
    ports integer,
    secret text NOT NULL,
    server text,
    community text,
    description text
);


ALTER TABLE public.nas OWNER TO rumalink_user;

--
-- Name: nas_devices; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_devices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    nas_ip character varying(45),
    nas_port integer DEFAULT 3799,
    secret text,
    provision_token text DEFAULT encode(public.gen_random_bytes(16), 'hex'::text),
    provision_url text,
    is_provisioned boolean DEFAULT false,
    provisioned_at timestamp with time zone,
    mikrotik_identity character varying(255),
    mikrotik_version character varying(50),
    mikrotik_board character varying(100),
    mikrotik_mac character varying(17),
    wan_ip character varying(45),
    is_online boolean DEFAULT false,
    last_seen timestamp with time zone,
    hotspot_enabled boolean DEFAULT false,
    pppoe_enabled boolean DEFAULT false,
    hotspot_profile character varying(100),
    pppoe_pool character varying(100),
    winbox_port integer DEFAULT 8291,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    antishare_enabled boolean DEFAULT false,
    antishare_max_devices integer DEFAULT 1,
    bridged_ports jsonb DEFAULT '[]'::jsonb,
    bridge_ports text DEFAULT 'ether2,ether3,ether4'::text,
    hotspot_interface text DEFAULT 'bridge1'::text,
    pppoe_interface text DEFAULT 'ether1'::text,
    gateway_ip text DEFAULT '192.168.88.1'::text,
    ip_pool_start text DEFAULT '192.168.88.10'::text,
    ip_pool_end text DEFAULT '192.168.88.254'::text,
    dns_primary text DEFAULT '8.8.8.8'::text,
    dns_secondary text DEFAULT '8.8.4.4'::text,
    hotspot_network character varying(20),
    hotspot_gateway character varying(45),
    hotspot_pool_start character varying(45),
    hotspot_pool_end character varying(45),
    mikrotik_api_user character varying(100),
    mikrotik_api_password text,
    remote_winbox_url text,
    provision_step character varying(30) DEFAULT 'pending'::character varying,
    cpu_load integer DEFAULT 0,
    memory_used_mb integer DEFAULT 0,
    memory_total_mb integer DEFAULT 0,
    disk_used_mb integer DEFAULT 0,
    disk_total_mb integer DEFAULT 0,
    uptime_seconds bigint DEFAULT 0,
    wan_interface character varying(50),
    available_interfaces character varying(255),
    wireguard_private_key text,
    wireguard_public_key text,
    wireguard_ip character varying(20),
    radius_secret character varying(64),
    winbox_proxy_port integer,
    isp_link_status character varying(10) DEFAULT 'unknown'::character varying,
    isp_link_changed_at timestamp with time zone,
    isp_link_last_checked timestamp with time zone,
    isp_link_consecutive_failures integer DEFAULT 0,
    isp_link_notifications_enabled boolean DEFAULT true,
    multi_wan_mode character varying(20) DEFAULT 'none'::character varying,
    wan1_interface character varying(20),
    wan1_gateway character varying(50),
    wan1_ping_target character varying(50) DEFAULT '8.8.8.8'::character varying,
    wan2_interface character varying(20),
    wan2_gateway character varying(50),
    wan2_ping_target character varying(50) DEFAULT '1.1.1.1'::character varying,
    multi_wan_check_interval integer DEFAULT 10,
    multi_wan_fail_threshold integer DEFAULT 3,
    lb_weight_wan1 integer DEFAULT 50,
    pcc_mode character varying(40) DEFAULT 'both-addresses'::character varying,
    multi_wan_applied_at timestamp with time zone,
    wan_quality_enabled boolean DEFAULT true,
    wan_quality_latency_ms integer DEFAULT 100,
    wan_quality_jitter_ms integer DEFAULT 30,
    wan_quality_loss_pct integer DEFAULT 2,
    wan_quality_trip_count integer DEFAULT 3,
    wan_quality_recover_count integer DEFAULT 20,
    wan_type character varying(10) DEFAULT 'dhcp'::character varying,
    wan_pppoe_user character varying(128),
    wan_pppoe_pass character varying(128),
    wan_static_ip character varying(32),
    wan_static_gw character varying(32),
    wan_selected boolean DEFAULT false,
    wan_quality_min_mbps numeric DEFAULT 3
);


ALTER TABLE public.nas_devices OWNER TO rumalink_user;

--
-- Name: nas_events; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nas_id uuid NOT NULL,
    isp_id uuid NOT NULL,
    event_type character varying(50) NOT NULL,
    message text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.nas_events OWNER TO rumalink_user;

--
-- Name: nas_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.nas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.nas_id_seq OWNER TO rumalink_user;

--
-- Name: nas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.nas_id_seq OWNED BY public.nas.id;


--
-- Name: nas_wan_links; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_wan_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nas_id uuid NOT NULL,
    "position" integer NOT NULL,
    name character varying(120),
    interface character varying(40) NOT NULL,
    gateway character varying(80),
    ping_target character varying(80) DEFAULT '8.8.8.8'::character varying,
    role character varying(30) DEFAULT 'dedicated'::character varying NOT NULL,
    lb_weight integer DEFAULT 50,
    enabled boolean DEFAULT true,
    current_status character varying(20) DEFAULT 'unknown'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    resolved_ip character varying(40),
    resolved_gateway character varying(40),
    last_checked_at timestamp with time zone,
    last_rtt character varying(30),
    is_active boolean DEFAULT false,
    internet_ok boolean DEFAULT false,
    in_load_balance boolean DEFAULT false NOT NULL,
    is_failover boolean DEFAULT false NOT NULL,
    failover_priority integer,
    last_latency_ms numeric,
    last_jitter_ms numeric,
    last_loss_pct numeric,
    quality_state character varying(12) DEFAULT 'good'::character varying,
    consec_degraded integer DEFAULT 0,
    consec_good integer DEFAULT 0,
    quality_parked boolean DEFAULT false,
    probe_verdict character varying(24),
    probe_stage character varying(24),
    dns_ms integer,
    connect_ms integer,
    fetch_ms integer,
    throughput_kbps integer,
    last_fetch_at timestamp with time zone,
    consec_fetch_fail integer DEFAULT 0,
    sample_history text DEFAULT ''::text,
    consec_slow integer DEFAULT 0,
    bytes_carried bigint DEFAULT 0,
    bytes_since timestamp with time zone DEFAULT now(),
    last_tx_bytes bigint,
    last_rx_bytes bigint,
    bytes_month_start date,
    in_pool boolean DEFAULT true,
    last_mbps numeric,
    tp_checked_at timestamp with time zone
);


ALTER TABLE public.nas_wan_links OWNER TO rumalink_user;

--
-- Name: nas_wan_policies; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_wan_policies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nas_id uuid NOT NULL,
    priority integer NOT NULL,
    name character varying(200),
    match_type character varying(40) NOT NULL,
    match_value text,
    action_type character varying(30) DEFAULT 'use_link'::character varying NOT NULL,
    target_link_id uuid,
    target_link_ids uuid[] DEFAULT ARRAY[]::uuid[],
    enabled boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.nas_wan_policies OWNER TO rumalink_user;

--
-- Name: nasreload; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nasreload (
    nasipaddress inet NOT NULL,
    reloadtime timestamp with time zone NOT NULL
);


ALTER TABLE public.nasreload OWNER TO rumalink_user;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid,
    admin_id uuid,
    type public.notification_type DEFAULT 'info'::public.notification_type,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false,
    link text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.notifications OWNER TO rumalink_user;

--
-- Name: payment_provider_configs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.payment_provider_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider character varying(32) NOT NULL,
    label character varying(120),
    merchant_code character varying(120),
    consumer_key text,
    consumer_secret text,
    api_key text,
    private_key text,
    public_key text,
    base_url text,
    is_sandbox boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.payment_provider_configs OWNER TO rumalink_user;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subscriber_id uuid,
    voucher_id uuid,
    amount numeric(10,2) NOT NULL,
    currency character varying(10) DEFAULT 'KES'::character varying,
    payment_method character varying(50) NOT NULL,
    payment_gateway character varying(50),
    transaction_id character varying(255),
    gateway_reference text,
    phone_number character varying(20),
    commission_amount numeric(10,2) DEFAULT 0.00,
    commission_rate numeric(5,4) DEFAULT 0.03,
    net_amount numeric(10,2),
    status public.payment_status DEFAULT 'pending'::public.payment_status,
    failure_reason text,
    description text,
    metadata jsonb,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    used_admin_credentials boolean DEFAULT false,
    forwarded_to character varying(100),
    forwarded_at timestamp with time zone,
    forward_status character varying(30),
    mpesa_phone character varying(20),
    mpesa_amount numeric(12,2),
    mpesa_name character varying(150),
    clearing_status character varying(24),
    cleared_at timestamp with time zone,
    intasend_invoice character varying(64),
    mpesa_receipt character varying(64),
    voucher_activated_at timestamp with time zone
);


ALTER TABLE public.payments OWNER TO rumalink_user;

--
-- Name: platform_secrets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.platform_secrets (
    key text NOT NULL,
    value text NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.platform_secrets OWNER TO postgres;

--
-- Name: platform_settings; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.platform_settings (
    key text NOT NULL,
    value numeric(12,4),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.platform_settings OWNER TO rumalink_user;

--
-- Name: pppoe_invoices; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_invoices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subscriber_id uuid NOT NULL,
    package_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    tax_amount numeric(10,2) DEFAULT 0.00,
    total_amount numeric(10,2) NOT NULL,
    billing_period_start date NOT NULL,
    billing_period_end date NOT NULL,
    due_date date NOT NULL,
    status public.payment_status DEFAULT 'pending'::public.payment_status,
    paid_at timestamp with time zone,
    payment_id uuid,
    reminder_sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pppoe_invoices OWNER TO rumalink_user;

--
-- Name: pppoe_packages; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_packages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    billing_cycle character varying(20) DEFAULT 'monthly'::character varying,
    bandwidth_down_mbps integer,
    bandwidth_up_mbps integer,
    data_limit_gb integer,
    burst_limit_mbps integer,
    burst_threshold_mbps integer,
    burst_time_seconds integer,
    mikrotik_profile character varying(100),
    address_pool character varying(100),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pppoe_packages OWNER TO rumalink_user;

--
-- Name: pppoe_sessions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subscriber_id uuid NOT NULL,
    nas_id uuid,
    radius_session_id character varying(255),
    framed_ip character varying(45),
    nas_ip character varying(45),
    caller_id character varying(100),
    bytes_downloaded bigint DEFAULT 0,
    bytes_uploaded bigint DEFAULT 0,
    session_time_seconds integer DEFAULT 0,
    status public.session_status DEFAULT 'active'::public.session_status,
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    terminate_cause character varying(100)
);


ALTER TABLE public.pppoe_sessions OWNER TO rumalink_user;

--
-- Name: pppoe_subscribers; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_subscribers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    package_id uuid NOT NULL,
    nas_id uuid,
    username character varying(100) NOT NULL,
    password_hash text NOT NULL,
    full_name character varying(255) NOT NULL,
    phone character varying(20),
    email character varying(255),
    id_number character varying(50),
    county character varying(100),
    town character varying(100),
    area character varying(100),
    physical_address text,
    static_ip character varying(45),
    mac_address character varying(17),
    status public.user_status DEFAULT 'active'::public.user_status,
    balance numeric(10,2) DEFAULT 0.00,
    next_billing_date timestamp with time zone,
    last_payment_date date,
    mikrotik_profile character varying(100),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    payment_sms_sent_at timestamp with time zone,
    expiry_reminder_sent boolean DEFAULT false,
    is_test boolean DEFAULT false,
    import_batch text
);


ALTER TABLE public.pppoe_subscribers OWNER TO rumalink_user;

--
-- Name: radacct; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radacct (
    radacctid bigint NOT NULL,
    acctsessionid character varying(64) NOT NULL,
    acctuniqueid character varying(32),
    username character varying(64),
    nasipaddress inet,
    nasportid character varying(15),
    nasporttype character varying(32),
    acctstarttime timestamp with time zone,
    acctstoptime timestamp with time zone,
    acctinterval bigint,
    acctsessiontime bigint,
    acctauthentic character varying(32),
    connectinfo_start text,
    connectinfo_stop text,
    acctinputoctets bigint,
    acctoutputoctets bigint,
    calledstationid character varying(50),
    callingstationid character varying(50),
    acctterminatecause character varying(32),
    servicetype character varying(32),
    framedprotocol character varying(32),
    framedipaddress inet,
    acctstart_delay bigint,
    acctdelivery_date timestamp with time zone DEFAULT now(),
    realm text,
    acctupdatetime timestamp with time zone,
    framedipv6address inet,
    framedipv6prefix text,
    framedinterfaceid text,
    delegatedipv6prefix inet
);


ALTER TABLE public.radacct OWNER TO rumalink_user;

--
-- Name: radacct_radacctid_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radacct_radacctid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radacct_radacctid_seq OWNER TO rumalink_user;

--
-- Name: radacct_radacctid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radacct_radacctid_seq OWNED BY public.radacct.radacctid;


--
-- Name: radcheck; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radcheck (
    id integer NOT NULL,
    username character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT ':='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radcheck OWNER TO rumalink_user;

--
-- Name: radcheck_delete_audit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.radcheck_delete_audit (
    id integer NOT NULL,
    deleted_at timestamp with time zone DEFAULT now(),
    username text,
    app_name text,
    client_addr inet,
    backend_pid integer,
    query_text text
);


ALTER TABLE public.radcheck_delete_audit OWNER TO postgres;

--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.radcheck_delete_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radcheck_delete_audit_id_seq OWNER TO postgres;

--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.radcheck_delete_audit_id_seq OWNED BY public.radcheck_delete_audit.id;


--
-- Name: radcheck_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radcheck_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radcheck_id_seq OWNER TO rumalink_user;

--
-- Name: radcheck_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radcheck_id_seq OWNED BY public.radcheck.id;


--
-- Name: radgroupcheck; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radgroupcheck (
    id integer NOT NULL,
    groupname character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT ':='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radgroupcheck OWNER TO rumalink_user;

--
-- Name: radgroupcheck_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radgroupcheck_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radgroupcheck_id_seq OWNER TO rumalink_user;

--
-- Name: radgroupcheck_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radgroupcheck_id_seq OWNED BY public.radgroupcheck.id;


--
-- Name: radgroupreply; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radgroupreply (
    id integer NOT NULL,
    groupname character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT '='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radgroupreply OWNER TO rumalink_user;

--
-- Name: radgroupreply_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radgroupreply_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radgroupreply_id_seq OWNER TO rumalink_user;

--
-- Name: radgroupreply_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radgroupreply_id_seq OWNED BY public.radgroupreply.id;


--
-- Name: radius_nas_clients; Type: VIEW; Schema: public; Owner: rumalink_user
--

CREATE VIEW public.radius_nas_clients AS
 SELECT nd.id,
    nd.name AS shortname,
    nd.wireguard_ip AS nasname,
    nd.radius_secret AS secret,
    i.company_name AS description,
    nd.isp_id,
    'mikrotik'::text AS type,
    NULL::text AS server
   FROM (public.nas_devices nd
     LEFT JOIN public.isps i ON ((i.id = nd.isp_id)))
  WHERE ((nd.wireguard_ip IS NOT NULL) AND (nd.radius_secret IS NOT NULL));


ALTER VIEW public.radius_nas_clients OWNER TO rumalink_user;

--
-- Name: radpostauth; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radpostauth (
    id bigint NOT NULL,
    username character varying(64) NOT NULL,
    pass character varying(64),
    reply character varying(32),
    authdate timestamp with time zone DEFAULT now(),
    class character varying(64)
);


ALTER TABLE public.radpostauth OWNER TO rumalink_user;

--
-- Name: radpostauth_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radpostauth_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radpostauth_id_seq OWNER TO rumalink_user;

--
-- Name: radpostauth_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radpostauth_id_seq OWNED BY public.radpostauth.id;


--
-- Name: radreply; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radreply (
    id integer NOT NULL,
    username character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT '='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radreply OWNER TO rumalink_user;

--
-- Name: radreply_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radreply_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radreply_id_seq OWNER TO rumalink_user;

--
-- Name: radreply_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radreply_id_seq OWNED BY public.radreply.id;


--
-- Name: radusergroup; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radusergroup (
    username character varying(64) NOT NULL,
    groupname character varying(64) NOT NULL,
    priority integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.radusergroup OWNER TO rumalink_user;

--
-- Name: shop_categories; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(100) NOT NULL,
    slug character varying(120),
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.shop_categories OWNER TO rumalink_user;

--
-- Name: shop_order_items; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_order_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid,
    product_name character varying(200) NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    line_total numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    product_image text
);


ALTER TABLE public.shop_order_items OWNER TO rumalink_user;

--
-- Name: shop_orders; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_number character varying(20) NOT NULL,
    customer_name character varying(150) NOT NULL,
    customer_phone character varying(20) NOT NULL,
    customer_email character varying(150),
    delivery_address text NOT NULL,
    delivery_notes text,
    subtotal numeric(10,2) DEFAULT 0 NOT NULL,
    delivery_fee numeric(10,2) DEFAULT 0 NOT NULL,
    total numeric(10,2) DEFAULT 0 NOT NULL,
    status character varying(30) DEFAULT 'pending_payment'::character varying NOT NULL,
    payment_status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    mpesa_checkout_id character varying(120),
    mpesa_receipt character varying(60),
    paid_at timestamp with time zone,
    notified_admin boolean DEFAULT false,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    delivery_type character varying(20) DEFAULT 'none'::character varying,
    delivery_location text,
    map_location text,
    admin_seen boolean DEFAULT false
);


ALTER TABLE public.shop_orders OWNER TO rumalink_user;

--
-- Name: shop_payments; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    phone_number character varying(20),
    mpesa_checkout_id character varying(120),
    mpesa_receipt character varying(60),
    status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    raw_callback jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.shop_payments OWNER TO rumalink_user;

--
-- Name: shop_products; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_products (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    category_id uuid,
    name character varying(200) NOT NULL,
    slug character varying(220),
    description text,
    price numeric(10,2) DEFAULT 0 NOT NULL,
    compare_price numeric(10,2),
    sku character varying(80),
    stock_qty integer DEFAULT 0,
    track_stock boolean DEFAULT true,
    image_url text,
    images jsonb DEFAULT '[]'::jsonb,
    is_active boolean DEFAULT true,
    is_featured boolean DEFAULT false,
    weight_kg numeric(8,2),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    supplier_name text,
    supplier_phone character varying(30),
    supplier_price numeric(10,2)
);


ALTER TABLE public.shop_products OWNER TO rumalink_user;

--
-- Name: shop_settings; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_settings (
    id integer DEFAULT 1 NOT NULL,
    default_delivery_fee numeric(10,2) DEFAULT 0,
    free_delivery_over numeric(10,2),
    currency character varying(10) DEFAULT 'KES'::character varying,
    shop_enabled boolean DEFAULT true,
    whatsapp_enabled boolean DEFAULT false,
    whatsapp_phone_id text,
    whatsapp_token text,
    whatsapp_admin_numbers text,
    order_prefix character varying(10) DEFAULT 'RL'::character varying,
    updated_at timestamp with time zone DEFAULT now(),
    free_delivery_locations text DEFAULT ''::text,
    CONSTRAINT single_row CHECK ((id = 1))
);


ALTER TABLE public.shop_settings OWNER TO rumalink_user;

--
-- Name: sms_credit_transactions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.sms_credit_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid,
    txn_type text NOT NULL,
    sms_count numeric(12,4) NOT NULL,
    unit_price numeric(10,4),
    unit_cost numeric(10,4),
    amount_paid numeric(12,2),
    profit numeric(12,4),
    isp_balance_after numeric(12,4),
    payment_id uuid,
    status text DEFAULT 'completed'::text,
    note text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.sms_credit_transactions OWNER TO rumalink_user;

--
-- Name: sms_logs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.sms_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    recipient character varying(20) NOT NULL,
    message text NOT NULL,
    gateway character varying(50),
    gateway_message_id text,
    status character varying(50) DEFAULT 'sent'::character varying,
    cost numeric(10,4),
    sent_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.sms_logs OWNER TO rumalink_user;

--
-- Name: sms_provider_config; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.sms_provider_config (
    id integer DEFAULT 1 NOT NULL,
    provider text DEFAULT 'talksasa'::text,
    api_key text,
    sender_id text,
    base_url text DEFAULT 'https://bulksms.talksasa.com/api/v3'::text,
    is_active boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT single_row CHECK ((id = 1))
);


ALTER TABLE public.sms_provider_config OWNER TO rumalink_user;

--
-- Name: support_replies; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.support_replies (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ticket_id uuid NOT NULL,
    author_type character varying(20) NOT NULL,
    author_id uuid NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.support_replies OWNER TO rumalink_user;

--
-- Name: support_tickets; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.support_tickets (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subject character varying(255) NOT NULL,
    message text NOT NULL,
    status character varying(50) DEFAULT 'open'::character varying,
    priority character varying(20) DEFAULT 'normal'::character varying,
    assigned_to uuid,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.support_tickets OWNER TO rumalink_user;

--
-- Name: usage_daily; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_daily (
    isp_id uuid NOT NULL,
    device_id uuid NOT NULL,
    username text NOT NULL,
    usage_day date NOT NULL,
    bytes_in bigint DEFAULT 0 NOT NULL,
    bytes_out bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.usage_daily OWNER TO postgres;

--
-- Name: usage_daily_pre_fix; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_daily_pre_fix (
    isp_id uuid,
    device_id uuid,
    username text,
    usage_day date,
    bytes_in bigint,
    bytes_out bigint,
    updated_at timestamp with time zone
);


ALTER TABLE public.usage_daily_pre_fix OWNER TO postgres;

--
-- Name: usage_session_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_session_state (
    acctsessionid text NOT NULL,
    acctuniqueid text,
    username text,
    isp_id uuid,
    device_id uuid,
    last_in bigint DEFAULT 0 NOT NULL,
    last_out bigint DEFAULT 0 NOT NULL,
    last_seen timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.usage_session_state OWNER TO postgres;

--
-- Name: usage_session_state_v2; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_session_state_v2 (
    acctuniqueid text NOT NULL,
    acctsessionid text,
    username text,
    isp_id uuid,
    device_id uuid,
    last_in bigint DEFAULT 0 NOT NULL,
    last_out bigint DEFAULT 0 NOT NULL,
    last_seen timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.usage_session_state_v2 OWNER TO postgres;

--
-- Name: verification_codes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.verification_codes (
    id bigint NOT NULL,
    isp_id uuid,
    channel text NOT NULL,
    target text NOT NULL,
    code_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    consumed_at timestamp with time zone,
    ip text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    selector text,
    CONSTRAINT verification_codes_channel_check CHECK ((channel = ANY (ARRAY['phone'::text, 'email'::text])))
);


ALTER TABLE public.verification_codes OWNER TO postgres;

--
-- Name: verification_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.verification_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.verification_codes_id_seq OWNER TO postgres;

--
-- Name: verification_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.verification_codes_id_seq OWNED BY public.verification_codes.id;


--
-- Name: voucher_batches; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.voucher_batches (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    package_id uuid NOT NULL,
    quantity integer NOT NULL,
    prefix character varying(20),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.voucher_batches OWNER TO rumalink_user;

--
-- Name: wan_usage_monthly; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wan_usage_monthly (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    link_id uuid NOT NULL,
    nas_id uuid,
    isp_id uuid,
    "position" integer,
    interface character varying(32),
    usage_month date NOT NULL,
    bytes_carried bigint DEFAULT 0 NOT NULL,
    archived_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.wan_usage_monthly OWNER TO postgres;

--
-- Name: _mac_delete_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._mac_delete_log ALTER COLUMN id SET DEFAULT nextval('public._mac_delete_log_id_seq'::regclass);


--
-- Name: _radreply_audit id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public._radreply_audit ALTER COLUMN id SET DEFAULT nextval('public._radreply_audit_id_seq'::regclass);


--
-- Name: email_provider_config id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_provider_config ALTER COLUMN id SET DEFAULT nextval('public.email_provider_config_id_seq'::regclass);


--
-- Name: nas id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas ALTER COLUMN id SET DEFAULT nextval('public.nas_id_seq'::regclass);


--
-- Name: radacct radacctid; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radacct ALTER COLUMN radacctid SET DEFAULT nextval('public.radacct_radacctid_seq'::regclass);


--
-- Name: radcheck id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radcheck ALTER COLUMN id SET DEFAULT nextval('public.radcheck_id_seq'::regclass);


--
-- Name: radcheck_delete_audit id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.radcheck_delete_audit ALTER COLUMN id SET DEFAULT nextval('public.radcheck_delete_audit_id_seq'::regclass);


--
-- Name: radgroupcheck id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupcheck ALTER COLUMN id SET DEFAULT nextval('public.radgroupcheck_id_seq'::regclass);


--
-- Name: radgroupreply id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupreply ALTER COLUMN id SET DEFAULT nextval('public.radgroupreply_id_seq'::regclass);


--
-- Name: radpostauth id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radpostauth ALTER COLUMN id SET DEFAULT nextval('public.radpostauth_id_seq'::regclass);


--
-- Name: radreply id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radreply ALTER COLUMN id SET DEFAULT nextval('public.radreply_id_seq'::regclass);


--
-- Name: verification_codes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_codes ALTER COLUMN id SET DEFAULT nextval('public.verification_codes_id_seq'::regclass);


--
-- Data for Name: _mac_delete_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._mac_delete_log (id, deleted_username, deleted_at, query, app) FROM stdin;
\.


--
-- Data for Name: _radreply_audit; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public._radreply_audit (id, username, attribute, deleted_at, pid, query) FROM stdin;
\.


--
-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.admins (id, name, email, password_hash, role, is_active, last_login, created_at, updated_at) FROM stdin;
e0556dcb-b203-4e85-b0c4-bd657bddcf62	RumaLink Admin	admin@rumalink.co.ke	$2a$12$lW4s6qSv6dP4ZBV4CMkUq.hwqqCiaphkhsZ6qELmJdG7MwF1axeje	superadmin	t	2026-07-29 06:05:14.966856+00	2026-05-24 08:18:35.982073+00	2026-05-24 08:18:35.982073+00
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.audit_logs (id, actor_type, actor_id, action, resource_type, resource_id, changes, ip_address, user_agent, created_at) FROM stdin;
\.


--
-- Data for Name: commissions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.commissions (id, isp_id, payment_id, amount, rate, period_month, period_year, is_settled, settled_at, created_at) FROM stdin;
\.


--
-- Data for Name: email_provider_config; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.email_provider_config (id, provider, smtp_host, smtp_port, smtp_secure, smtp_user, smtp_pass, from_email, from_name, is_active, updated_at, logo_url, logo_bg) FROM stdin;
1	resend	smtp.resend.com	465	t	resend	re_GC6FvMH6_YDoRrQeYEbwRxjrGaAyPW3DB	noreply@rumalinkenterprise.online	RumaLink Enterprise	t	2026-07-26 05:42:41.484707+00	https://rumalinkenterprise.online/logo.png	#262d37
\.


--
-- Data for Name: hotspot_bound_devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hotspot_bound_devices (id, isp_id, name, mac_address, buyer_phone, active_voucher_id, bound_ip, package_id, expires_at, is_bound, created_at, updated_at, usage_base_in, usage_base_out, last_ctr_in, last_ctr_out) FROM stdin;
\.


--
-- Data for Name: hotspot_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_packages (id, isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: hotspot_sessions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_sessions (id, isp_id, voucher_id, nas_id, radius_session_id, mac_address, ip_address, nas_ip, bytes_downloaded, bytes_uploaded, session_time_seconds, status, started_at, ended_at, terminate_cause) FROM stdin;
\.


--
-- Data for Name: hotspot_vouchers; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_vouchers (id, isp_id, package_id, nas_id, code, batch_id, status, used_by_mac, used_by_ip, used_at, expires_at, bytes_downloaded, bytes_uploaded, time_used_seconds, is_paid, amount_paid, payment_method, payment_reference, created_at, updated_at, buyer_phone, sms_sent, expiry_sms_sent, payment_id, is_test, password, is_tv, tv_mac, created_by_isp, import_batch) FROM stdin;
\.


--
-- Data for Name: intasend_withdrawals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.intasend_withdrawals (id, isp_id, method, destination, gross_amount, fee_amount, net_amount, below_threshold, status, intasend_ref, intasend_state, failure_reason, balance_before, balance_after, metadata, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: isp_captive_portal; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_captive_portal (id, isp_id, template, primary_color, secondary_color, logo_url, welcome_title, welcome_subtitle, bg_image_url, show_logo, show_powered_by, custom_css, updated_at, support_number, support_label, enable_tv_mode, notif_enabled, notif_title, notif_message, notif_severity, notif_start, notif_end, media_enabled, media_type, media_video_url, media_images, media_interval, media_fit) FROM stdin;
\.


--
-- Data for Name: isp_payment_methods; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_payment_methods (id, isp_id, method_type, label, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials, till_number, paybill_number, account_reference, bank_name, account_name, account_number, branch, forward_to_type, forward_to_number, forward_to_name, is_active, is_verified, is_default, created_at, updated_at, provider) FROM stdin;
\.


--
-- Data for Name: isp_platform_invoices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_platform_invoices (id, isp_id, period_month, period_year, pppoe_user_count, amount_per_user, total_amount, status, due_date, paid_at, created_at, invoice_number, invoice_type, payment_id, hotspot_revenue, hotspot_fee, hotspot_rate, pppoe_fee, window_start, window_end, period_expires_at) FROM stdin;
\.


--
-- Data for Name: isp_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_transactions (id, isp_id, type, amount, balance_before, balance_after, description, reference_id, created_at) FROM stdin;
\.


--
-- Data for Name: isps; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isps (id, company_name, owner_name, email, phone, password_hash, plan_type, status, county, town, address, api_key, api_secret, webhook_url, wallet_balance, commission_rate, pppoe_rate_per_user, total_earned, total_commission_paid, sms_gateway, sms_api_key, sms_sender_id, logo_url, timezone, currency, email_verified, email_verify_token, password_reset_token, password_reset_expires, trial_ends_at, last_login, created_at, updated_at, sms_username, sms_partner_id, sms_api_secret, support_number, hotspot_counter, subscription_started_at, license_expires_at, billing_window_start, license_status, billing_exempt, sms_balance, phone_verified, phone_verified_at, email_verified_at) FROM stdin;
07282edb-0d6d-4833-9d43-62c924089214	Rumalink	Benard	admin@rumalink.co.ke	0117195942	$2a$12$EDpHw8jDGTSix0gPk1niG.LxqgmDmzoZeB4kTWXaIkwaFJ6f7yGOi	both	suspended	Nairobi	Nairobi	\N	cae04cc5-e4bc-45ba-9ac7-aab0ef3364ec	0208033d7caea5e2f5e85fcf5e24080b0738b97f599ce8963dd18efada3beb48	\N	0.00	0.0300	32.25	0.00	0.00	\N	\N	\N	\N	Africa/Nairobi	KES	f	cca35fa2-bb29-4111-904c-9fecbcfdfcf3	\N	\N	2026-08-28 06:11:15.289205+00	\N	2026-07-29 06:11:15.289205+00	2026-07-29 06:13:10.278388+00	\N	\N	\N	\N	0	\N	\N	\N	trial	f	50.0000	f	\N	\N
\.


--
-- Data for Name: mac_auth_cache; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.mac_auth_cache (id, mac_address, isp_id, package_id, authorized_at, expires_at, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: mpesa_configs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.mpesa_configs (id, isp_id, shortcode, consumer_key, consumer_secret, passkey, callback_url, is_sandbox, is_active, created_at, updated_at, is_admin_config) FROM stdin;
67b0cf20-31dd-4a56-bd92-ab55f9f288cf	\N	4322307	7V4yYILZxVLaYRalxSX7vLNKARpAItO9YwOzlA0pCCQ4KZQ0	b0eWBg6Cv0G558cMO6OhAbAKrJJ5wDvMAybO9axDEB1ZVastiVAAjh2HKwrz0VRw	3317f5d8845fbe32c8e8435e1b79934d36ae1c303f9383b5d8a35ac36d4720b6	\N	f	t	2026-07-29 06:09:00.438128+00	2026-07-29 06:09:00.438128+00	t
\.


--
-- Data for Name: mpesa_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.mpesa_transactions (id, isp_id, payment_id, checkout_request_id, merchant_request_id, result_code, result_desc, amount, mpesa_receipt, phone, transaction_date, status, raw_callback, created_at) FROM stdin;
\.


--
-- Data for Name: nas; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas (id, nasname, shortname, type, ports, secret, server, community, description) FROM stdin;
\.


--
-- Data for Name: nas_devices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_devices (id, isp_id, name, description, nas_ip, nas_port, secret, provision_token, provision_url, is_provisioned, provisioned_at, mikrotik_identity, mikrotik_version, mikrotik_board, mikrotik_mac, wan_ip, is_online, last_seen, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port, created_at, updated_at, antishare_enabled, antishare_max_devices, bridged_ports, bridge_ports, hotspot_interface, pppoe_interface, gateway_ip, ip_pool_start, ip_pool_end, dns_primary, dns_secondary, hotspot_network, hotspot_gateway, hotspot_pool_start, hotspot_pool_end, mikrotik_api_user, mikrotik_api_password, remote_winbox_url, provision_step, cpu_load, memory_used_mb, memory_total_mb, disk_used_mb, disk_total_mb, uptime_seconds, wan_interface, available_interfaces, wireguard_private_key, wireguard_public_key, wireguard_ip, radius_secret, winbox_proxy_port, isp_link_status, isp_link_changed_at, isp_link_last_checked, isp_link_consecutive_failures, isp_link_notifications_enabled, multi_wan_mode, wan1_interface, wan1_gateway, wan1_ping_target, wan2_interface, wan2_gateway, wan2_ping_target, multi_wan_check_interval, multi_wan_fail_threshold, lb_weight_wan1, pcc_mode, multi_wan_applied_at, wan_quality_enabled, wan_quality_latency_ms, wan_quality_jitter_ms, wan_quality_loss_pct, wan_quality_trip_count, wan_quality_recover_count, wan_type, wan_pppoe_user, wan_pppoe_pass, wan_static_ip, wan_static_gw, wan_selected, wan_quality_min_mbps) FROM stdin;
\.


--
-- Data for Name: nas_events; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_events (id, nas_id, isp_id, event_type, message, created_at) FROM stdin;
\.


--
-- Data for Name: nas_wan_links; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_links (id, nas_id, "position", name, interface, gateway, ping_target, role, lb_weight, enabled, current_status, created_at, resolved_ip, resolved_gateway, last_checked_at, last_rtt, is_active, internet_ok, in_load_balance, is_failover, failover_priority, last_latency_ms, last_jitter_ms, last_loss_pct, quality_state, consec_degraded, consec_good, quality_parked, probe_verdict, probe_stage, dns_ms, connect_ms, fetch_ms, throughput_kbps, last_fetch_at, consec_fetch_fail, sample_history, consec_slow, bytes_carried, bytes_since, last_tx_bytes, last_rx_bytes, bytes_month_start, in_pool, last_mbps, tp_checked_at) FROM stdin;
\.


--
-- Data for Name: nas_wan_policies; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_policies (id, nas_id, priority, name, match_type, match_value, action_type, target_link_id, target_link_ids, enabled, created_at) FROM stdin;
\.


--
-- Data for Name: nasreload; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nasreload (nasipaddress, reloadtime) FROM stdin;
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.notifications (id, isp_id, admin_id, type, title, message, is_read, link, created_at) FROM stdin;
e56be611-28d0-41c9-ab59-dd1a319b85df	\N	\N	info	New ISP Registered	Rumalink has registered on the platform (both plan)	f	\N	2026-07-29 06:11:16.364553+00
28cb8b94-9e83-4cf5-9f5a-8f116b503750	07282edb-0d6d-4833-9d43-62c924089214	\N	warning	Account Status Update	Your account has been suspended.	f	\N	2026-07-29 06:13:10.280539+00
\.


--
-- Data for Name: payment_provider_configs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.payment_provider_configs (id, provider, label, merchant_code, consumer_key, consumer_secret, api_key, private_key, public_key, base_url, is_sandbox, is_active, created_at, updated_at) FROM stdin;
a4c097d0-d422-422a-b556-db68de15d422	jenga	\N	1587205221	\N	9qFZ7w5zKti9nXVlK8Zl28Cr3Z14oD	7bg07O+pMst83rwQavCCtLKQiA693tOKJeNS3VMzRRG0CI1FtNbdC4U9ULNu2V0ePAU/P1V1oOBrbCeyUsv2Og==	-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDZgGWIQcLQArlq\nVzrF4SV3KoA9QMChkSzbwruSL5k08wICvVyeJDGWQrhuViMmD8zts7Pi4crINnj/\n1A3Xu1j50CrLUl8g0LkutaUJmlBFLromrWItuzG44fNJcAfa6+NS3bsFXONFz9Lw\npPraasG+01XH5SlOC9eO+1sArs3Yt+s/GiDlYvbX28ALMjfX6tUV1vzSjBsvacRS\ndLCXCGZrM/K5pYKjyd3UgigRUsnWmgzNVsV3buXZqh936UcHvT48YHo0TuqYsq7d\nsV0OchtliY4P29eKHLt4gpP5b1TyWl4Mt9inQOwT8UrU6AHrEiECBRTfkQXS5JPi\nT2BSmzL/AgMBAAECggEAEdBpQHlsxjjnswG1YusRJ8sq2Rl6TYfEiue03jQya63l\nm1zWftTyQywJ/m6x27AanEA5YQ4WQkMeTCUA0NhCFHMYz8tacEEekbVRJAUbQvdU\nFs8UbGNzHwEeoIRIMgWOk/hslQ1dFGUBRWV11R+ktVQkDmApSGbbsmHJVWtImWtp\nD7Rf+7XE6Zel+IbAFnHhICnaUOxoSWE3nNmOhYyRBniL+2r4v7LgRonZLWrcfAJ6\nxz9kLzvKcFS4xRMY1aEcfV+g5yu8rVWJlp4ImsL/qFJXfezhW5lN6lI2DxUv/3DQ\ntLTDQktPl4nX2MdZb+RTocPN9yIw9ZOlV9QueOtT4QKBgQDsfAA9sgQVNXsC46+s\nUuEpDRRVyj5iSCSBOZnILwMq+I1ZLWbZE4rhyK8XuEjkAApRbu8gxbEwB/1rHLnO\nl/9QIogveDJBOJoXT0N2KiI1EAJJ1byarvqKYpJ9qt4rXKSHHsuXK05K+jtvngh0\n3IZTEqQ15nx4KUNXK+RSyc1EHwKBgQDrc1ysEZK2dIXzUfNduuwrtJpWvPjOEyXL\nedNIe6MShpeo8KAyCtCmFY6yFbkuwIiu+hbqy+zunEZnV5wtCurbDaAKHuys/LG8\npiyoRE2SSMjxhlTcAejV+iacQIicsJMxgZ1CYgJYPiQhzGi4G2apBXaQoFraS/dH\nUNw2lpU1IQKBgEoxSR4SCIfi5HnulwHYar2nVdbogZPyEEnemWmdnj/QBQCSZu75\n25uki5JEhdHKVXJg/HLqswFfsFj3hS/UrgwlGVbTPekKagWgH4kmBN9i62TgwrBA\n72eVL2Jvxg4SnaequLLvqjuJsDX/faW0Pgw4D/69FhXY1EC4C4URvO1/AoGAbpL9\nAKo4FovepIjmHCy+4T+uA/I3fsArTcXm3fGCgh7HdsWa1iWSG42gOC5Pi49MIbC9\ntoMSwHSP89SHOfgYl8tsT5R6XjtGVWxNKLD7JSodhKArli8nY+ZY36THA59BYUyX\nyCczJrH4Ug8nVt83dUVli0JjqIVomgt1gAV0CUECgYEAnbNrjveCgrQO5EjjEJdQ\nIT609vwNH8C1ejhBKjnTUN5+mLeiufDKt86Bn0a0qftpyZVO2DGdgHb10+reZJdM\n7l06KDwHPej5b2XemSITbJSZy2oLeI4qhBa/dc61NhrgtXlFp/zfSFcGVkEduVmu\nTXA8NtHeQFrZ0mdh8TnNX6Y=\n-----END PRIVATE KEY-----	\N	https://uat.finserve.africa	t	t	2026-06-22 09:55:15.524141+00	2026-06-22 10:01:08.802393+00
216d93ea-0023-436c-9f8d-f5050ebd40ec	intasend	IntaSend (Admin)	\N	\N	\N	ISPubKey_test_c15f0971-500a-4094-ade6-bda28e35acea	ISSecretKey_test_6c53c610-5e1f-47fe-b9d1-008d1a2a18e7	\N	https://sandbox.intasend.com/api/v1/	t	t	2026-07-10 12:08:52.135529+00	2026-07-11 15:09:14.748197+00
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.payments (id, isp_id, subscriber_id, voucher_id, amount, currency, payment_method, payment_gateway, transaction_id, gateway_reference, phone_number, commission_amount, commission_rate, net_amount, status, failure_reason, description, metadata, paid_at, created_at, updated_at, used_admin_credentials, forwarded_to, forwarded_at, forward_status, mpesa_phone, mpesa_amount, mpesa_name, clearing_status, cleared_at, intasend_invoice, mpesa_receipt, voucher_activated_at) FROM stdin;
\.


--
-- Data for Name: platform_secrets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.platform_secrets (key, value, updated_at) FROM stdin;
intasend_webhook_challenge	benrade@d25410282017	2026-07-11 13:24:38.759417+00
\.


--
-- Data for Name: platform_settings; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.platform_settings (key, value, updated_at) FROM stdin;
sms_price_per_sms	0.5000	2026-06-27 07:42:44.358443+00
sms_cost_per_sms	0.3500	2026-06-27 07:42:44.360594+00
sms_signup_bonus	50.0000	2026-06-27 07:42:44.361833+00
hotspot_commission_rate	0.0300	2026-07-03 15:11:49.786236+00
pppoe_per_user_fee	50.0000	2026-07-03 15:11:49.789272+00
intasend_collection_cashapp_pct	0.0450	2026-07-10 12:08:52.082679+00
intasend_payout_mpesa_flat	100.0000	2026-07-10 12:08:52.082679+00
intasend_payout_bank_flat	100.0000	2026-07-10 12:08:52.082679+00
intasend_payout_bank_pct	0.0000	2026-07-10 12:08:52.082679+00
intasend_payout_b2b_flat	100.0000	2026-07-10 12:08:52.082679+00
intasend_max_fee_ratio	0.1000	2026-07-10 12:08:52.082679+00
intasend_method_mpesa_enabled	1.0000	2026-07-10 12:08:52.082679+00
intasend_method_bank_enabled	1.0000	2026-07-10 12:08:52.082679+00
intasend_method_b2b_enabled	1.0000	2026-07-10 12:08:52.082679+00
intasend_collection_mpesa_pct	0.0300	2026-07-15 23:14:55.083241+00
intasend_collection_mpesa_max	400.0000	2026-07-15 23:14:55.085713+00
intasend_collection_card_pct	0.0350	2026-07-15 23:14:55.087134+00
intasend_collection_cardintl_pct	0.0450	2026-07-15 23:14:55.088616+00
intasend_payout_mpesa_pct	0.0150	2026-07-15 23:14:55.089897+00
intasend_payout_mpesa_min	10.0000	2026-07-15 23:14:55.09109+00
intasend_payout_mpesa_max	50.0000	2026-07-15 23:14:55.09224+00
intasend_payout_bank_t1_max	10000.0000	2026-07-15 23:14:55.093375+00
intasend_payout_bank_t1_fee	100.0000	2026-07-15 23:14:55.094592+00
intasend_payout_bank_t2_max	50000.0000	2026-07-15 23:14:55.095744+00
intasend_payout_bank_t2_fee	150.0000	2026-07-15 23:14:55.096974+00
intasend_payout_bank_t3_max	100000.0000	2026-07-15 23:14:55.098175+00
intasend_payout_bank_t3_fee	200.0000	2026-07-15 23:14:55.099361+00
intasend_payout_bank_t4_max	500000.0000	2026-07-15 23:14:55.100607+00
intasend_payout_bank_t4_fee	400.0000	2026-07-15 23:14:55.10176+00
intasend_payout_bank_t5_max	999999.0000	2026-07-15 23:14:55.102873+00
intasend_payout_bank_t5_fee	500.0000	2026-07-15 23:14:55.104022+00
intasend_payout_paybill_t1_max	1000.0000	2026-07-15 23:14:55.105208+00
intasend_payout_paybill_t1_fee	30.0000	2026-07-15 23:14:55.106342+00
intasend_payout_paybill_t2_max	3500.0000	2026-07-15 23:14:55.107481+00
intasend_payout_paybill_t2_fee	50.0000	2026-07-15 23:14:55.108695+00
intasend_payout_paybill_t3_max	5000.0000	2026-07-15 23:14:55.109889+00
intasend_payout_paybill_t3_fee	70.0000	2026-07-15 23:14:55.111453+00
intasend_payout_paybill_t4_max	10000.0000	2026-07-15 23:14:55.112617+00
intasend_payout_paybill_t4_fee	80.0000	2026-07-15 23:14:55.113897+00
intasend_payout_paybill_t5_max	30000.0000	2026-07-15 23:14:55.115816+00
intasend_payout_paybill_t5_fee	100.0000	2026-07-15 23:14:55.117729+00
intasend_payout_paybill_t6_max	45000.0000	2026-07-15 23:14:55.118886+00
intasend_payout_paybill_t6_fee	130.0000	2026-07-15 23:14:55.120017+00
intasend_payout_paybill_t7_max	150000.0000	2026-07-15 23:14:55.121276+00
intasend_payout_paybill_t7_fee	150.0000	2026-07-15 23:14:55.122329+00
intasend_payout_till_threshold	10000.0000	2026-07-15 23:14:55.123441+00
intasend_payout_till_fee_low	20.0000	2026-07-15 23:14:55.124611+00
intasend_payout_till_fee_high	40.0000	2026-07-15 23:14:55.125742+00
intasend_method_paybill_enabled	1.0000	2026-07-15 23:14:55.126882+00
intasend_method_till_enabled	1.0000	2026-07-15 23:14:55.127986+00
\.


--
-- Data for Name: pppoe_invoices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_invoices (id, isp_id, subscriber_id, package_id, amount, tax_amount, total_amount, billing_period_start, billing_period_end, due_date, status, paid_at, payment_id, reminder_sent_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: pppoe_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_packages (id, isp_id, name, description, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, burst_limit_mbps, burst_threshold_mbps, burst_time_seconds, mikrotik_profile, address_pool, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: pppoe_sessions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_sessions (id, isp_id, subscriber_id, nas_id, radius_session_id, framed_ip, nas_ip, caller_id, bytes_downloaded, bytes_uploaded, session_time_seconds, status, started_at, ended_at, terminate_cause) FROM stdin;
\.


--
-- Data for Name: pppoe_subscribers; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_subscribers (id, isp_id, package_id, nas_id, username, password_hash, full_name, phone, email, id_number, county, town, area, physical_address, static_ip, mac_address, status, balance, next_billing_date, last_payment_date, mikrotik_profile, created_at, updated_at, payment_sms_sent_at, expiry_reminder_sent, is_test, import_batch) FROM stdin;
\.


--
-- Data for Name: radacct; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radacct (radacctid, acctsessionid, acctuniqueid, username, nasipaddress, nasportid, nasporttype, acctstarttime, acctstoptime, acctinterval, acctsessiontime, acctauthentic, connectinfo_start, connectinfo_stop, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, acctterminatecause, servicetype, framedprotocol, framedipaddress, acctstart_delay, acctdelivery_date, realm, acctupdatetime, framedipv6address, framedipv6prefix, framedinterfaceid, delegatedipv6prefix) FROM stdin;
1	81100005	a20d7720f8a00d824a499a87cdc28f26	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-07-29 05:53:50+00	\N	300	1200	RADIUS		\N	25558440	58031923	rumalink	50:0F:F5:36:A7:50	\N	Framed-User	PPP	100.64.0.254	\N	2026-07-29 06:08:51.343495+00	\N	2026-07-29 06:13:50+00	\N	\N	\N	\N
\.


--
-- Data for Name: radcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radcheck (id, username, attribute, op, value) FROM stdin;
\.


--
-- Data for Name: radcheck_delete_audit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.radcheck_delete_audit (id, deleted_at, username, app_name, client_addr, backend_pid, query_text) FROM stdin;
1	2026-07-24 14:12:02.404139+00	R1@4742d080	psql	\N	26265	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
2	2026-07-24 14:13:02.177616+00	R1@4742d080	psql	\N	26342	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
3	2026-07-24 14:14:02.323813+00	R1@4742d080	psql	\N	26417	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
4	2026-07-24 14:15:02.205289+00	R1@4742d080	psql	\N	26493	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
5	2026-07-24 14:16:02.023408+00	R1@4742d080	psql	\N	26561	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
6	2026-07-24 14:17:01.602301+00	R1@4742d080	psql	\N	26714	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
7	2026-07-24 14:18:02.647098+00	R1@4742d080	psql	\N	26790	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
8	2026-07-24 14:19:02.235129+00	R1@4742d080	psql	\N	26857	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
9	2026-07-24 14:20:02.571804+00	R1@4742d080	psql	\N	27008	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
10	2026-07-24 14:21:01.372115+00	R1@4742d080	psql	\N	27078	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
11	2026-07-24 14:22:02.206022+00	R1@4742d080	psql	\N	27155	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
12	2026-07-24 14:23:01.945059+00	R1@4742d080	psql	\N	27223	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
13	2026-07-24 14:27:01.612163+00	R1@4742d080		127.0.0.1	27588	DELETE FROM radcheck WHERE username = $1 OR username = $2
14	2026-07-24 14:27:49.042687+00	R1@4742d080		127.0.0.1	27586	DELETE FROM radcheck WHERE username = $1
15	2026-07-24 14:28:49.044839+00	R1@4742d080		127.0.0.1	27661	DELETE FROM radcheck WHERE username = $1
16	2026-07-24 14:49:08.768476+00	R1@4742d080		127.0.0.1	29855	DELETE FROM radcheck WHERE username = $1
17	2026-07-24 14:50:00.811112+00	R1@4742d080		127.0.0.1	29855	DELETE FROM radcheck WHERE username = $1 OR username = $2
18	2026-07-24 14:53:21.607466+00	R1@4742d080		127.0.0.1	30261	DELETE FROM radcheck WHERE username = $1 OR username = $2
19	2026-07-24 14:53:40.842547+00	R1@4742d080		127.0.0.1	30260	DELETE FROM radcheck WHERE username = $1
20	2026-07-24 14:54:23.664188+00	R1@4742d080		127.0.0.1	30334	DELETE FROM radcheck WHERE username = $1
21	2026-07-24 14:54:40.847506+00	R1@4742d080		127.0.0.1	30333	DELETE FROM radcheck WHERE username = $1
22	2026-07-24 14:55:40.843341+00	R1@4742d080		127.0.0.1	30419	DELETE FROM radcheck WHERE username = $1
23	2026-07-24 14:56:00.998495+00	R1@4742d080		127.0.0.1	30418	DELETE FROM radcheck WHERE username = $1 OR username = $2
24	2026-07-24 15:00:59.198746+00	R2@4742d080		127.0.0.1	30840	DELETE FROM radcheck WHERE username = $1
25	2026-07-24 15:00:59.395255+00	R2@4742d080		127.0.0.1	30840	DELETE FROM radcheck WHERE username = $1
26	2026-07-24 15:01:00.17784+00	R2@4742d080		127.0.0.1	30774	DELETE FROM radcheck WHERE username = $1 OR username = $2
27	2026-07-24 15:18:52.837098+00	R1@4742d080		127.0.0.1	32507	DELETE FROM radcheck WHERE username = $1 OR username = $2
28	2026-07-24 15:18:52.914469+00	R1@4742d080		127.0.0.1	32507	DELETE FROM radcheck WHERE username = $1
29	2026-07-24 15:21:52.17838+00	R1@4742d080		127.0.0.1	32739	DELETE FROM radcheck WHERE username = $1 OR username = $2
30	2026-07-24 15:21:56.185925+00	8E:DD:81:17:79:C6		127.0.0.1	32739	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
31	2026-07-24 15:22:06.010325+00	R1@4742d080		127.0.0.1	32745	DELETE FROM radcheck WHERE username = $1
32	2026-07-24 15:23:06.01868+00	R1@4742d080		127.0.0.1	32813	DELETE FROM radcheck WHERE username = $1
33	2026-07-24 15:50:00.164645+00	R1@4742d080		127.0.0.1	35509	DELETE FROM radcheck WHERE username = $1 OR username = $2
34	2026-07-24 15:50:13.982347+00	66:87:6A:49:95:DA		127.0.0.1	35583	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
35	2026-07-24 15:52:00.839958+00	R1@4742d080		127.0.0.1	35662	DELETE FROM radcheck WHERE username = $1 OR username = $2
36	2026-07-25 05:50:59.268425+00	66:87:6A:49:95:DA		127.0.0.1	100774	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
37	2026-07-25 05:52:59.303869+00	8E:DD:81:17:79:C6		127.0.0.1	100880	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
38	2026-07-25 06:07:58.568943+00	R1@4742d080		127.0.0.1	101986	DELETE FROM radcheck WHERE username = $1
39	2026-07-25 06:08:58.572834+00	R1@4742d080		127.0.0.1	102170	DELETE FROM radcheck WHERE username = $1
40	2026-07-25 06:15:02.99937+00	R3@4742d080		127.0.0.1	103799	DELETE FROM radcheck WHERE username = $1
41	2026-07-25 06:15:03.501408+00	R3@4742d080		127.0.0.1	103799	DELETE FROM radcheck WHERE username = $1
42	2026-07-25 06:15:03.703977+00	R3@4742d080		127.0.0.1	103799	DELETE FROM radcheck WHERE username = $1
43	2026-07-25 06:16:03.341733+00	R3@4742d080		127.0.0.1	103891	DELETE FROM radcheck WHERE username = $1 OR username = $2
44	2026-07-25 15:01:01.740425+00	R2@4742d080	psql	\N	157177	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
45	2026-07-25 15:51:55.486476+00	66:87:6A:49:95:DA		127.0.0.1	162032	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
46	2026-07-25 15:52:01.839856+00	R1@4742d080	psql	\N	162074	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
47	2026-07-26 06:16:01.32502+00	R3@4742d080	psql	\N	48562	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
48	2026-07-26 13:40:07.011693+00	R4@4742d080		127.0.0.1	92303	DELETE FROM radcheck WHERE username = $1 OR username = $2
49	2026-07-26 18:40:21.897129+00	3A:AD:23:80:40:76		127.0.0.1	121251	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
50	2026-07-26 18:41:01.963796+00	R4@4742d080	psql	\N	121378	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
51	2026-07-28 06:59:18.984584+00	R1@4742d080		127.0.0.1	129556	DELETE FROM radcheck WHERE username = $1 OR username = $2
52	2026-07-28 06:59:21.713499+00	66:87:6A:49:95:DA		127.0.0.1	129556	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
53	2026-07-28 07:18:47.65754+00	R3@4742d080		127.0.0.1	131764	DELETE FROM radcheck WHERE username = $1
54	2026-07-28 07:28:49.402769+00	R1@4742d080		127.0.0.1	132719	DELETE FROM radcheck WHERE username = $1
55	2026-07-28 07:29:00.992664+00	R1@4742d080		127.0.0.1	132809	DELETE FROM radcheck WHERE username = $1 OR username = $2
56	2026-07-29 04:28:28.875823+00	R1@4742d080		127.0.0.1	98807	DELETE FROM radcheck WHERE username = $1 OR username = $2
57	2026-07-29 04:28:38.196187+00	66:87:6A:49:95:DA		127.0.0.1	98897	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
58	2026-07-29 05:13:55.442851+00	R1@4742d080		127.0.0.1	103557	DELETE FROM radcheck WHERE username = $1 OR username = $2
59	2026-07-29 05:14:38.17738+00	66:87:6A:49:95:DA		127.0.0.1	103653	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
60	2026-07-29 05:27:22.032711+00	R1@4742d080		127.0.0.1	105044	DELETE FROM radcheck WHERE username = $1
61	2026-07-29 05:28:00.146342+00	R1@4742d080		127.0.0.1	105132	DELETE FROM radcheck WHERE username = $1 OR username = $2
62	2026-07-29 05:54:37.947175+00	R1@4742d080		127.0.0.1	107625	DELETE FROM radcheck WHERE username = $1
63	2026-07-29 05:55:37.943418+00	R1@4742d080		127.0.0.1	107738	DELETE FROM radcheck WHERE username = $1
\.


--
-- Data for Name: radgroupcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radgroupcheck (id, groupname, attribute, op, value) FROM stdin;
\.


--
-- Data for Name: radgroupreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radgroupreply (id, groupname, attribute, op, value) FROM stdin;
\.


--
-- Data for Name: radpostauth; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radpostauth (id, username, pass, reply, authdate, class) FROM stdin;
\.


--
-- Data for Name: radreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radreply (id, username, attribute, op, value) FROM stdin;
\.


--
-- Data for Name: radusergroup; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radusergroup (username, groupname, priority) FROM stdin;
\.


--
-- Data for Name: shop_categories; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_categories (id, name, slug, sort_order, is_active, created_at) FROM stdin;
537d7139-6d7e-4669-a193-4c27b400c0ff	Routers	routers	1	t	2026-07-01 23:00:28.454669+00
f1de54a8-b025-4e88-b713-52a0f376c7d4	Antennas	antennas	2	t	2026-07-01 23:00:28.454669+00
2b662eaf-8508-4b99-b479-867355860290	Cables & Connectors	cables-connectors	3	t	2026-07-01 23:00:28.454669+00
db8ad8db-c06a-4d93-9be9-2b018fac5707	Accessories	accessories	4	t	2026-07-01 23:00:28.454669+00
\.


--
-- Data for Name: shop_order_items; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_order_items (id, order_id, product_id, product_name, unit_price, quantity, line_total, created_at, product_image) FROM stdin;
\.


--
-- Data for Name: shop_orders; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_orders (id, order_number, customer_name, customer_phone, customer_email, delivery_address, delivery_notes, subtotal, delivery_fee, total, status, payment_status, mpesa_checkout_id, mpesa_receipt, paid_at, notified_admin, metadata, created_at, updated_at, delivery_type, delivery_location, map_location, admin_seen) FROM stdin;
\.


--
-- Data for Name: shop_payments; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_payments (id, order_id, amount, phone_number, mpesa_checkout_id, mpesa_receipt, status, raw_callback, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: shop_products; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_products (id, category_id, name, slug, description, price, compare_price, sku, stock_qty, track_stock, image_url, images, is_active, is_featured, weight_kg, created_at, updated_at, supplier_name, supplier_phone, supplier_price) FROM stdin;
ed29d286-5e56-4a13-9390-3b8daced26c6	537d7139-6d7e-4669-a193-4c27b400c0ff	China Mobile	china-mobile	Wall Breaker	15.00	\N	\N	47	t	/uploads/products/prod_1782981577338_883042.webp	[]	t	f	\N	2026-07-02 08:40:00.781026+00	2026-07-02 08:40:00.781026+00	Me	0740258495	10.00
1666f7e3-8782-47a4-a1fb-a3922cb4f59e	537d7139-6d7e-4669-a193-4c27b400c0ff	TP-Link	tp-link	Upto 300Mbps	10.00	\N	\N	39	t	/uploads/products/prod_1782977765100_426047.webp	[]	t	f	\N	2026-07-02 07:36:24.992146+00	2026-07-02 07:38:09.531926+00	\N	\N	\N
\.


--
-- Data for Name: shop_settings; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_settings (id, default_delivery_fee, free_delivery_over, currency, shop_enabled, whatsapp_enabled, whatsapp_phone_id, whatsapp_token, whatsapp_admin_numbers, order_prefix, updated_at, free_delivery_locations) FROM stdin;
1	0.00	4000.00	KES	t	f	\N	\N		RL	2026-07-02 08:16:57.534298+00	Nairobi CBD, Dandora, Kasarani
\.


--
-- Data for Name: sms_credit_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_credit_transactions (id, isp_id, txn_type, sms_count, unit_price, unit_cost, amount_paid, profit, isp_balance_after, payment_id, status, note, created_at) FROM stdin;
4401331b-cf8b-4336-904b-ebcdfe4779b7	07282edb-0d6d-4833-9d43-62c924089214	signup_bonus	50.0000	\N	\N	\N	\N	50.0000	\N	completed	Welcome bonus on signup	2026-07-29 06:11:15.302209+00
\.


--
-- Data for Name: sms_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_logs (id, isp_id, recipient, message, gateway, gateway_message_id, status, cost, sent_at) FROM stdin;
\.


--
-- Data for Name: sms_provider_config; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_provider_config (id, provider, api_key, sender_id, base_url, is_active, updated_at) FROM stdin;
1	talksasa	1109|mgZZ8Ybp3dVmuZyqraO5gKV4vx8ULnFoQwQod4Oua56532b7	TALKSASA	https://bulksms.talksasa.com/api/v3	t	2026-06-27 09:11:01.50878+00
\.


--
-- Data for Name: support_replies; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.support_replies (id, ticket_id, author_type, author_id, message, created_at) FROM stdin;
\.


--
-- Data for Name: support_tickets; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.support_tickets (id, isp_id, subject, message, status, priority, assigned_to, resolved_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: usage_daily; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily (isp_id, device_id, username, usage_day, bytes_in, bytes_out, updated_at) FROM stdin;
\.


--
-- Data for Name: usage_daily_pre_fix; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily_pre_fix (isp_id, device_id, username, usage_day, bytes_in, bytes_out, updated_at) FROM stdin;
\.


--
-- Data for Name: usage_session_state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_session_state (acctsessionid, acctuniqueid, username, isp_id, device_id, last_in, last_out, last_seen) FROM stdin;
\.


--
-- Data for Name: usage_session_state_v2; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_session_state_v2 (acctuniqueid, acctsessionid, username, isp_id, device_id, last_in, last_out, last_seen) FROM stdin;
\.


--
-- Data for Name: verification_codes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_codes (id, isp_id, channel, target, code_hash, expires_at, attempts, consumed_at, ip, created_at, selector) FROM stdin;
1	07282edb-0d6d-4833-9d43-62c924089214	email	admin@rumalink.co.ke	aa46f21858e6aa7e.48b1bc15630165b22d23a1f1baea220af7a99f6253e32a3c690c95cdd681204e	2026-07-30 06:11:16.372333+00	0	\N	102.205.237.69	2026-07-29 06:11:16.372333+00	31a3cb3b286b
\.


--
-- Data for Name: voucher_batches; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.voucher_batches (id, isp_id, package_id, quantity, prefix, created_at) FROM stdin;
\.


--
-- Data for Name: wan_usage_monthly; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wan_usage_monthly (id, link_id, nas_id, isp_id, "position", interface, usage_month, bytes_carried, archived_at) FROM stdin;
\.


--
-- Name: _mac_delete_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public._mac_delete_log_id_seq', 1, false);


--
-- Name: _radreply_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public._radreply_audit_id_seq', 1, false);


--
-- Name: email_provider_config_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.email_provider_config_id_seq', 1, true);


--
-- Name: nas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.nas_id_seq', 1, false);


--
-- Name: radacct_radacctid_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radacct_radacctid_seq', 1, true);


--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.radcheck_delete_audit_id_seq', 63, true);


--
-- Name: radcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radcheck_id_seq', 1, false);


--
-- Name: radgroupcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radgroupcheck_id_seq', 1, false);


--
-- Name: radgroupreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radgroupreply_id_seq', 1, false);


--
-- Name: radpostauth_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radpostauth_id_seq', 1, false);


--
-- Name: radreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radreply_id_seq', 1, false);


--
-- Name: verification_codes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_codes_id_seq', 1, true);


--
-- Name: admins admins_email_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_email_key UNIQUE (email);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: commissions commissions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_pkey PRIMARY KEY (id);


--
-- Name: email_provider_config email_provider_config_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_provider_config
    ADD CONSTRAINT email_provider_config_pkey PRIMARY KEY (id);


--
-- Name: hotspot_bound_devices hotspot_bound_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hotspot_bound_devices
    ADD CONSTRAINT hotspot_bound_devices_pkey PRIMARY KEY (id);


--
-- Name: hotspot_packages hotspot_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_packages
    ADD CONSTRAINT hotspot_packages_pkey PRIMARY KEY (id);


--
-- Name: hotspot_sessions hotspot_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_pkey PRIMARY KEY (id);


--
-- Name: hotspot_vouchers hotspot_vouchers_code_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_code_key UNIQUE (code);


--
-- Name: hotspot_vouchers hotspot_vouchers_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_pkey PRIMARY KEY (id);


--
-- Name: intasend_withdrawals intasend_withdrawals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.intasend_withdrawals
    ADD CONSTRAINT intasend_withdrawals_pkey PRIMARY KEY (id);


--
-- Name: isp_captive_portal isp_captive_portal_isp_id_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_captive_portal
    ADD CONSTRAINT isp_captive_portal_isp_id_key UNIQUE (isp_id);


--
-- Name: isp_captive_portal isp_captive_portal_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_captive_portal
    ADD CONSTRAINT isp_captive_portal_pkey PRIMARY KEY (id);


--
-- Name: isp_payment_methods isp_payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_payment_methods
    ADD CONSTRAINT isp_payment_methods_pkey PRIMARY KEY (id);


--
-- Name: isp_platform_invoices isp_platform_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_platform_invoices
    ADD CONSTRAINT isp_platform_invoices_pkey PRIMARY KEY (id);


--
-- Name: isp_transactions isp_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_transactions
    ADD CONSTRAINT isp_transactions_pkey PRIMARY KEY (id);


--
-- Name: isps isps_email_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isps
    ADD CONSTRAINT isps_email_key UNIQUE (email);


--
-- Name: isps isps_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isps
    ADD CONSTRAINT isps_pkey PRIMARY KEY (id);


--
-- Name: mac_auth_cache mac_auth_cache_mac_address_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_mac_address_key UNIQUE (mac_address);


--
-- Name: mac_auth_cache mac_auth_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_pkey PRIMARY KEY (id);


--
-- Name: mpesa_configs mpesa_configs_isp_id_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_configs
    ADD CONSTRAINT mpesa_configs_isp_id_key UNIQUE (isp_id);


--
-- Name: mpesa_configs mpesa_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_configs
    ADD CONSTRAINT mpesa_configs_pkey PRIMARY KEY (id);


--
-- Name: mpesa_transactions mpesa_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_transactions
    ADD CONSTRAINT mpesa_transactions_pkey PRIMARY KEY (id);


--
-- Name: nas_devices nas_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_devices
    ADD CONSTRAINT nas_devices_pkey PRIMARY KEY (id);


--
-- Name: nas_events nas_events_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_events
    ADD CONSTRAINT nas_events_pkey PRIMARY KEY (id);


--
-- Name: nas nas_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas
    ADD CONSTRAINT nas_pkey PRIMARY KEY (id);


--
-- Name: nas_wan_links nas_wan_links_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_links
    ADD CONSTRAINT nas_wan_links_pkey PRIMARY KEY (id);


--
-- Name: nas_wan_policies nas_wan_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_policies
    ADD CONSTRAINT nas_wan_policies_pkey PRIMARY KEY (id);


--
-- Name: nasreload nasreload_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nasreload
    ADD CONSTRAINT nasreload_pkey PRIMARY KEY (nasipaddress);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: payment_provider_configs payment_provider_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payment_provider_configs
    ADD CONSTRAINT payment_provider_configs_pkey PRIMARY KEY (id);


--
-- Name: payment_provider_configs payment_provider_configs_provider_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payment_provider_configs
    ADD CONSTRAINT payment_provider_configs_provider_key UNIQUE (provider);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: platform_secrets platform_secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.platform_secrets
    ADD CONSTRAINT platform_secrets_pkey PRIMARY KEY (key);


--
-- Name: platform_settings platform_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.platform_settings
    ADD CONSTRAINT platform_settings_pkey PRIMARY KEY (key);


--
-- Name: pppoe_invoices pppoe_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_pkey PRIMARY KEY (id);


--
-- Name: pppoe_packages pppoe_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_packages
    ADD CONSTRAINT pppoe_packages_pkey PRIMARY KEY (id);


--
-- Name: pppoe_sessions pppoe_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_pkey PRIMARY KEY (id);


--
-- Name: pppoe_subscribers pppoe_subscribers_isp_id_username_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_isp_id_username_key UNIQUE (isp_id, username);


--
-- Name: pppoe_subscribers pppoe_subscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_pkey PRIMARY KEY (id);


--
-- Name: radacct radacct_acctuniqueid_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radacct
    ADD CONSTRAINT radacct_acctuniqueid_key UNIQUE (acctuniqueid);


--
-- Name: radacct radacct_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radacct
    ADD CONSTRAINT radacct_pkey PRIMARY KEY (radacctid);


--
-- Name: radcheck_delete_audit radcheck_delete_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.radcheck_delete_audit
    ADD CONSTRAINT radcheck_delete_audit_pkey PRIMARY KEY (id);


--
-- Name: radcheck radcheck_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radcheck
    ADD CONSTRAINT radcheck_pkey PRIMARY KEY (id);


--
-- Name: radgroupcheck radgroupcheck_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupcheck
    ADD CONSTRAINT radgroupcheck_pkey PRIMARY KEY (id);


--
-- Name: radgroupreply radgroupreply_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupreply
    ADD CONSTRAINT radgroupreply_pkey PRIMARY KEY (id);


--
-- Name: radpostauth radpostauth_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radpostauth
    ADD CONSTRAINT radpostauth_pkey PRIMARY KEY (id);


--
-- Name: radreply radreply_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radreply
    ADD CONSTRAINT radreply_pkey PRIMARY KEY (id);


--
-- Name: shop_categories shop_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_categories
    ADD CONSTRAINT shop_categories_pkey PRIMARY KEY (id);


--
-- Name: shop_categories shop_categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_categories
    ADD CONSTRAINT shop_categories_slug_key UNIQUE (slug);


--
-- Name: shop_order_items shop_order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_order_items
    ADD CONSTRAINT shop_order_items_pkey PRIMARY KEY (id);


--
-- Name: shop_orders shop_orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT shop_orders_order_number_key UNIQUE (order_number);


--
-- Name: shop_orders shop_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT shop_orders_pkey PRIMARY KEY (id);


--
-- Name: shop_payments shop_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_payments
    ADD CONSTRAINT shop_payments_pkey PRIMARY KEY (id);


--
-- Name: shop_products shop_products_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT shop_products_pkey PRIMARY KEY (id);


--
-- Name: shop_settings shop_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_settings
    ADD CONSTRAINT shop_settings_pkey PRIMARY KEY (id);


--
-- Name: sms_credit_transactions sms_credit_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_credit_transactions
    ADD CONSTRAINT sms_credit_transactions_pkey PRIMARY KEY (id);


--
-- Name: sms_logs sms_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_logs
    ADD CONSTRAINT sms_logs_pkey PRIMARY KEY (id);


--
-- Name: sms_provider_config sms_provider_config_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_provider_config
    ADD CONSTRAINT sms_provider_config_pkey PRIMARY KEY (id);


--
-- Name: support_replies support_replies_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_replies
    ADD CONSTRAINT support_replies_pkey PRIMARY KEY (id);


--
-- Name: support_tickets support_tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_tickets
    ADD CONSTRAINT support_tickets_pkey PRIMARY KEY (id);


--
-- Name: usage_daily usage_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_daily
    ADD CONSTRAINT usage_daily_pkey PRIMARY KEY (isp_id, username, usage_day, device_id);


--
-- Name: usage_session_state usage_session_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_session_state
    ADD CONSTRAINT usage_session_state_pkey PRIMARY KEY (acctsessionid);


--
-- Name: usage_session_state_v2 usage_session_state_v2_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_session_state_v2
    ADD CONSTRAINT usage_session_state_v2_pkey PRIMARY KEY (acctuniqueid);


--
-- Name: verification_codes verification_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_codes
    ADD CONSTRAINT verification_codes_pkey PRIMARY KEY (id);


--
-- Name: voucher_batches voucher_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.voucher_batches
    ADD CONSTRAINT voucher_batches_pkey PRIMARY KEY (id);


--
-- Name: wan_usage_monthly wan_usage_monthly_link_id_usage_month_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wan_usage_monthly
    ADD CONSTRAINT wan_usage_monthly_link_id_usage_month_key UNIQUE (link_id, usage_month);


--
-- Name: wan_usage_monthly wan_usage_monthly_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wan_usage_monthly
    ADD CONSTRAINT wan_usage_monthly_pkey PRIMARY KEY (id);


--
-- Name: commissions_payment_id_uidx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE UNIQUE INDEX commissions_payment_id_uidx ON public.commissions USING btree (payment_id);


--
-- Name: hbd_isp_mac_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX hbd_isp_mac_uniq ON public.hotspot_bound_devices USING btree (isp_id, upper(mac_address));


--
-- Name: hotspot_bound_devices_isp_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX hotspot_bound_devices_isp_idx ON public.hotspot_bound_devices USING btree (isp_id);


--
-- Name: hotspot_bound_devices_isp_mac_uidx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX hotspot_bound_devices_isp_mac_uidx ON public.hotspot_bound_devices USING btree (isp_id, lower(mac_address));


--
-- Name: hv_isp_phone_norm; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX hv_isp_phone_norm ON public.hotspot_vouchers USING btree (isp_id, "right"(regexp_replace((buyer_phone)::text, '[^0-9]'::text, ''::text, 'g'::text), 9)) WHERE (is_tv IS NOT TRUE);


--
-- Name: idx_captive_portal_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_captive_portal_isp ON public.isp_captive_portal USING btree (isp_id);


--
-- Name: idx_hotspot_sessions_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_hotspot_sessions_status ON public.hotspot_sessions USING btree (status);


--
-- Name: idx_isp_captive_portal_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_captive_portal_isp ON public.isp_captive_portal USING btree (isp_id);


--
-- Name: idx_isp_cp_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_cp_isp ON public.isp_captive_portal USING btree (isp_id);


--
-- Name: idx_isp_payment_methods_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_payment_methods_isp ON public.isp_payment_methods USING btree (isp_id);


--
-- Name: idx_isp_pm_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_pm_isp ON public.isp_payment_methods USING btree (isp_id);


--
-- Name: idx_isps_api_key; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isps_api_key ON public.isps USING btree (api_key);


--
-- Name: idx_isps_email; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isps_email ON public.isps USING btree (email);


--
-- Name: idx_isps_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isps_status ON public.isps USING btree (status);


--
-- Name: idx_isw_isp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_isw_isp ON public.intasend_withdrawals USING btree (isp_id, created_at DESC);


--
-- Name: idx_isw_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_isw_status ON public.intasend_withdrawals USING btree (status);


--
-- Name: idx_mac_cache_active; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_mac_cache_active ON public.mac_auth_cache USING btree (is_active, expires_at);


--
-- Name: idx_mac_cache_mac; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_mac_cache_mac ON public.mac_auth_cache USING btree (mac_address);


--
-- Name: idx_nas_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_isp ON public.nas_devices USING btree (isp_id);


--
-- Name: idx_nas_token; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_token ON public.nas_devices USING btree (provision_token);


--
-- Name: idx_nas_wan_links_nas_id; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_wan_links_nas_id ON public.nas_wan_links USING btree (nas_id);


--
-- Name: idx_nas_wan_policies_nas_id; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_wan_policies_nas_id ON public.nas_wan_policies USING btree (nas_id);


--
-- Name: idx_notif_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_notif_isp ON public.notifications USING btree (isp_id);


--
-- Name: idx_pay_clearing; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pay_clearing ON public.payments USING btree (payment_gateway, status, clearing_status);


--
-- Name: idx_payment_methods_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payment_methods_isp ON public.isp_payment_methods USING btree (isp_id);


--
-- Name: idx_payments_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_isp ON public.payments USING btree (isp_id);


--
-- Name: idx_payments_isp_created; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_isp_created ON public.payments USING btree (isp_id, created_at DESC);


--
-- Name: idx_payments_mpesa_phone; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_mpesa_phone ON public.payments USING btree (mpesa_phone);


--
-- Name: idx_payments_phone_number; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_phone_number ON public.payments USING btree (phone_number);


--
-- Name: idx_payments_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_status ON public.payments USING btree (status);


--
-- Name: idx_pppoe_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pppoe_isp ON public.pppoe_subscribers USING btree (isp_id);


--
-- Name: idx_pppoe_sessions_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pppoe_sessions_status ON public.pppoe_sessions USING btree (status);


--
-- Name: idx_pppoe_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pppoe_username ON public.pppoe_subscribers USING btree (username);


--
-- Name: idx_radacct_active; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_active ON public.radacct USING btree (acctstoptime) WHERE (acctstoptime IS NULL);


--
-- Name: idx_radacct_nas; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_nas ON public.radacct USING btree (nasipaddress);


--
-- Name: idx_radacct_session; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_session ON public.radacct USING btree (acctsessionid);


--
-- Name: idx_radacct_starttime; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_starttime ON public.radacct USING btree (acctstarttime);


--
-- Name: idx_radacct_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_username ON public.radacct USING btree (username);


--
-- Name: idx_radcheck_user; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radcheck_user ON public.radcheck USING btree (username);


--
-- Name: idx_radcheck_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radcheck_username ON public.radcheck USING btree (username);


--
-- Name: idx_radpostauth_date; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radpostauth_date ON public.radpostauth USING btree (authdate);


--
-- Name: idx_radpostauth_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radpostauth_username ON public.radpostauth USING btree (username);


--
-- Name: idx_radreply_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radreply_username ON public.radreply USING btree (username);


--
-- Name: idx_shop_order_items_order; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_order_items_order ON public.shop_order_items USING btree (order_id);


--
-- Name: idx_shop_orders_checkout; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_orders_checkout ON public.shop_orders USING btree (mpesa_checkout_id);


--
-- Name: idx_shop_orders_created; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_orders_created ON public.shop_orders USING btree (created_at DESC);


--
-- Name: idx_shop_orders_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_orders_status ON public.shop_orders USING btree (status);


--
-- Name: idx_shop_payments_checkout; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_payments_checkout ON public.shop_payments USING btree (mpesa_checkout_id);


--
-- Name: idx_shop_payments_order; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_payments_order ON public.shop_payments USING btree (order_id);


--
-- Name: idx_shop_products_active; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_products_active ON public.shop_products USING btree (is_active);


--
-- Name: idx_shop_products_category; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_products_category ON public.shop_products USING btree (category_id);


--
-- Name: idx_sms_credit_created; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_sms_credit_created ON public.sms_credit_transactions USING btree (created_at);


--
-- Name: idx_sms_credit_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_sms_credit_isp ON public.sms_credit_transactions USING btree (isp_id);


--
-- Name: idx_sms_credit_type; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_sms_credit_type ON public.sms_credit_transactions USING btree (txn_type);


--
-- Name: idx_usage_daily_device_day; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usage_daily_device_day ON public.usage_daily USING btree (device_id, usage_day);


--
-- Name: idx_usage_daily_isp_day; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usage_daily_isp_day ON public.usage_daily USING btree (isp_id, usage_day);


--
-- Name: idx_uss2_last_seen; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_uss2_last_seen ON public.usage_session_state_v2 USING btree (last_seen);


--
-- Name: idx_vouchers_code; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_code ON public.hotspot_vouchers USING btree (code);


--
-- Name: idx_vouchers_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_isp ON public.hotspot_vouchers USING btree (isp_id);


--
-- Name: idx_vouchers_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_status ON public.hotspot_vouchers USING btree (status);


--
-- Name: idx_wum_month; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_wum_month ON public.wan_usage_monthly USING btree (usage_month);


--
-- Name: nas_nasname; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX nas_nasname ON public.nas USING btree (nasname);


--
-- Name: radacct_active_session_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radacct_active_session_idx ON public.radacct USING btree (acctuniqueid) WHERE (acctstoptime IS NULL);


--
-- Name: radacct_start_user_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radacct_start_user_idx ON public.radacct USING btree (acctstarttime, username);


--
-- Name: radcheck_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radcheck_username ON public.radcheck USING btree (username, attribute);


--
-- Name: radgroupcheck_groupname; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radgroupcheck_groupname ON public.radgroupcheck USING btree (groupname, attribute);


--
-- Name: radgroupreply_groupname; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radgroupreply_groupname ON public.radgroupreply USING btree (groupname, attribute);


--
-- Name: radpostauth_class_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radpostauth_class_idx ON public.radpostauth USING btree (class);


--
-- Name: radpostauth_username_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radpostauth_username_idx ON public.radpostauth USING btree (username);


--
-- Name: radreply_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radreply_username ON public.radreply USING btree (username, attribute);


--
-- Name: radusergroup_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radusergroup_username ON public.radusergroup USING btree (username);


--
-- Name: uniq_open_platform_invoice; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE UNIQUE INDEX uniq_open_platform_invoice ON public.isp_platform_invoices USING btree (isp_id) WHERE (status = 'pending'::public.payment_status);


--
-- Name: vc_isp_channel; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vc_isp_channel ON public.verification_codes USING btree (isp_id, channel, created_at DESC);


--
-- Name: vc_selector; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vc_selector ON public.verification_codes USING btree (selector);


--
-- Name: vc_target_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vc_target_time ON public.verification_codes USING btree (target, created_at DESC);


--
-- Name: radcheck rl_radcheck_del_audit; Type: TRIGGER; Schema: public; Owner: rumalink_user
--

CREATE TRIGGER rl_radcheck_del_audit BEFORE DELETE ON public.radcheck FOR EACH ROW EXECUTE FUNCTION public.rl_audit_radcheck_delete();


--
-- Name: commissions commissions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: commissions commissions_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: hotspot_bound_devices hbd_isp_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hotspot_bound_devices
    ADD CONSTRAINT hbd_isp_fk FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: hotspot_packages hotspot_packages_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_packages
    ADD CONSTRAINT hotspot_packages_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: hotspot_packages hotspot_packages_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_packages
    ADD CONSTRAINT hotspot_packages_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: hotspot_sessions hotspot_sessions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: hotspot_sessions hotspot_sessions_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: hotspot_sessions hotspot_sessions_voucher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES public.hotspot_vouchers(id);


--
-- Name: hotspot_vouchers hotspot_vouchers_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: hotspot_vouchers hotspot_vouchers_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: hotspot_vouchers hotspot_vouchers_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.hotspot_packages(id);


--
-- Name: intasend_withdrawals intasend_withdrawals_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.intasend_withdrawals
    ADD CONSTRAINT intasend_withdrawals_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: isp_captive_portal isp_captive_portal_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_captive_portal
    ADD CONSTRAINT isp_captive_portal_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: isp_payment_methods isp_payment_methods_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_payment_methods
    ADD CONSTRAINT isp_payment_methods_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: isp_platform_invoices isp_platform_invoices_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_platform_invoices
    ADD CONSTRAINT isp_platform_invoices_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: isp_platform_invoices isp_platform_invoices_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_platform_invoices
    ADD CONSTRAINT isp_platform_invoices_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: isp_transactions isp_transactions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_transactions
    ADD CONSTRAINT isp_transactions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: mac_auth_cache mac_auth_cache_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: mac_auth_cache mac_auth_cache_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.hotspot_packages(id) ON DELETE SET NULL;


--
-- Name: mpesa_configs mpesa_configs_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_configs
    ADD CONSTRAINT mpesa_configs_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: mpesa_transactions mpesa_transactions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_transactions
    ADD CONSTRAINT mpesa_transactions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: mpesa_transactions mpesa_transactions_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_transactions
    ADD CONSTRAINT mpesa_transactions_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: nas_devices nas_devices_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_devices
    ADD CONSTRAINT nas_devices_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: nas_events nas_events_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_events
    ADD CONSTRAINT nas_events_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: nas_events nas_events_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_events
    ADD CONSTRAINT nas_events_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE CASCADE;


--
-- Name: nas_wan_links nas_wan_links_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_links
    ADD CONSTRAINT nas_wan_links_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE CASCADE;


--
-- Name: nas_wan_policies nas_wan_policies_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_policies
    ADD CONSTRAINT nas_wan_policies_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE CASCADE;


--
-- Name: nas_wan_policies nas_wan_policies_target_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_policies
    ADD CONSTRAINT nas_wan_policies_target_link_id_fkey FOREIGN KEY (target_link_id) REFERENCES public.nas_wan_links(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.admins(id);


--
-- Name: notifications notifications_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: payments payments_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: payments payments_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.pppoe_subscribers(id);


--
-- Name: payments payments_voucher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES public.hotspot_vouchers(id);


--
-- Name: pppoe_invoices pppoe_invoices_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: pppoe_invoices pppoe_invoices_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.pppoe_packages(id);


--
-- Name: pppoe_invoices pppoe_invoices_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: pppoe_invoices pppoe_invoices_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.pppoe_subscribers(id);


--
-- Name: pppoe_packages pppoe_packages_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_packages
    ADD CONSTRAINT pppoe_packages_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: pppoe_sessions pppoe_sessions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: pppoe_sessions pppoe_sessions_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: pppoe_sessions pppoe_sessions_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.pppoe_subscribers(id);


--
-- Name: pppoe_subscribers pppoe_subscribers_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: pppoe_subscribers pppoe_subscribers_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: pppoe_subscribers pppoe_subscribers_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.pppoe_packages(id);


--
-- Name: shop_order_items shop_order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_order_items
    ADD CONSTRAINT shop_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.shop_orders(id) ON DELETE CASCADE;


--
-- Name: shop_order_items shop_order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_order_items
    ADD CONSTRAINT shop_order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.shop_products(id) ON DELETE SET NULL;


--
-- Name: shop_payments shop_payments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_payments
    ADD CONSTRAINT shop_payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.shop_orders(id) ON DELETE CASCADE;


--
-- Name: shop_products shop_products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT shop_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.shop_categories(id) ON DELETE SET NULL;


--
-- Name: sms_credit_transactions sms_credit_transactions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_credit_transactions
    ADD CONSTRAINT sms_credit_transactions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: sms_logs sms_logs_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_logs
    ADD CONSTRAINT sms_logs_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: support_replies support_replies_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_replies
    ADD CONSTRAINT support_replies_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.support_tickets(id);


--
-- Name: support_tickets support_tickets_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_tickets
    ADD CONSTRAINT support_tickets_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.admins(id);


--
-- Name: support_tickets support_tickets_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_tickets
    ADD CONSTRAINT support_tickets_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: verification_codes verification_codes_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_codes
    ADD CONSTRAINT verification_codes_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: voucher_batches voucher_batches_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.voucher_batches
    ADD CONSTRAINT voucher_batches_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: voucher_batches voucher_batches_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.voucher_batches
    ADD CONSTRAINT voucher_batches_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.hotspot_packages(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO rumalink_user;


--
-- Name: TABLE _mac_delete_log; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public._mac_delete_log TO rumalink_user;


--
-- Name: SEQUENCE _mac_delete_log_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public._mac_delete_log_id_seq TO rumalink_user;


--
-- Name: TABLE email_provider_config; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.email_provider_config TO rumalink_user;


--
-- Name: SEQUENCE email_provider_config_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.email_provider_config_id_seq TO rumalink_user;


--
-- Name: TABLE hotspot_bound_devices; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.hotspot_bound_devices TO rumalink_user;


--
-- Name: TABLE intasend_withdrawals; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.intasend_withdrawals TO rumalink_user;


--
-- Name: TABLE platform_secrets; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.platform_secrets TO rumalink_user;


--
-- Name: TABLE radcheck_delete_audit; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.radcheck_delete_audit TO rumalink_user;


--
-- Name: SEQUENCE radcheck_delete_audit_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.radcheck_delete_audit_id_seq TO rumalink_user;


--
-- Name: TABLE usage_daily; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_daily TO rumalink_user;


--
-- Name: TABLE usage_daily_pre_fix; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_daily_pre_fix TO rumalink_user;


--
-- Name: TABLE usage_session_state; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_session_state TO rumalink_user;


--
-- Name: TABLE usage_session_state_v2; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_session_state_v2 TO rumalink_user;


--
-- Name: TABLE verification_codes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.verification_codes TO rumalink_user;


--
-- Name: SEQUENCE verification_codes_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.verification_codes_id_seq TO rumalink_user;


--
-- Name: TABLE wan_usage_monthly; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.wan_usage_monthly TO rumalink_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO rumalink_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO rumalink_user;


--
-- PostgreSQL database dump complete
--

\unrestrict vZqJpB1pvS149pFufT1nwfeP2gWCI6uD27u1epCemlWs9JSJ1CS4re8SlqZZvEQ

