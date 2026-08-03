--
-- PostgreSQL database dump
--

\restrict iZsv1gZWdjjSdhjHGz1p1VxsjWb1CWUVWbtZAdZuyGiZfM5R3YJnmThj7IE4HXt

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
    import_batch text,
    purchased_by_mac character varying
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
    provider character varying(32),
    environment character varying(50) DEFAULT 'production'::character varying
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
-- Name: system_health; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_health (
    id bigint NOT NULL,
    sampled_at timestamp with time zone DEFAULT now() NOT NULL,
    load1 numeric,
    cpu_steal numeric,
    mem_total_mb integer,
    mem_avail_mb integer,
    swap_used_mb integer,
    disk_pct integer,
    freeradius_mb integer,
    node_mb integer,
    pg_conns integer,
    routers_total integer,
    routers_down integer,
    status text
);


ALTER TABLE public.system_health OWNER TO postgres;

--
-- Name: system_health_alerts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_health_alerts (
    id bigint NOT NULL,
    metric text NOT NULL,
    severity text NOT NULL,
    value numeric,
    threshold numeric,
    message text,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone
);


ALTER TABLE public.system_health_alerts OWNER TO postgres;

--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.system_health_alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_health_alerts_id_seq OWNER TO postgres;

--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.system_health_alerts_id_seq OWNED BY public.system_health_alerts.id;


--
-- Name: system_health_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.system_health_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_health_id_seq OWNER TO postgres;

--
-- Name: system_health_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.system_health_id_seq OWNED BY public.system_health.id;


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
-- Name: system_health id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health ALTER COLUMN id SET DEFAULT nextval('public.system_health_id_seq'::regclass);


--
-- Name: system_health_alerts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health_alerts ALTER COLUMN id SET DEFAULT nextval('public.system_health_alerts_id_seq'::regclass);


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
e0556dcb-b203-4e85-b0c4-bd657bddcf62	RumaLink Admin	admin@rumalink.co.ke	$2a$12$lW4s6qSv6dP4ZBV4CMkUq.hwqqCiaphkhsZ6qELmJdG7MwF1axeje	superadmin	t	2026-08-03 14:52:47.830021+00	2026-05-24 08:18:35.982073+00	2026-05-24 08:18:35.982073+00
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
d68dd8a8-e73f-49ad-b665-19e688427bf7	cc49de72-5ea8-402b-865a-c2fa66698151	7d0c7d83-f4fa-4e9e-a78f-79696ac4264d	0.30	0.0300	\N	\N	f	\N	2026-08-03 12:17:25.080584+00
ac82c542-87db-47d0-bc72-d8e03a2e0b07	cc49de72-5ea8-402b-865a-c2fa66698151	bf2228e1-201d-4d4d-89f1-1738b13ce3e7	0.15	0.0300	\N	\N	f	\N	2026-08-03 12:26:24.539328+00
605eeb96-41ea-42de-99f5-8c892a78933f	cc49de72-5ea8-402b-865a-c2fa66698151	1cfe897b-6b24-4761-917c-04515be7a3c1	0.15	0.0300	\N	\N	f	\N	2026-08-03 12:32:24.393274+00
782a8938-b639-4fc5-96e4-f3ad7656fb88	cc49de72-5ea8-402b-865a-c2fa66698151	6d05e9ce-df61-46d7-a85c-f8055c1fe213	0.15	0.0300	\N	\N	f	\N	2026-08-03 12:34:25.114104+00
3fab02e4-51fc-4f55-8375-3dc143a5905a	cc49de72-5ea8-402b-865a-c2fa66698151	eea9258b-6fbd-40a1-b9cb-ad41bef67190	0.15	0.0300	\N	\N	f	\N	2026-08-03 13:57:48.669724+00
06346201-9417-439a-866f-32da21de431a	cc49de72-5ea8-402b-865a-c2fa66698151	bd3cdd19-2faf-44b8-be5b-bff1a2bf5bec	0.00	0.0300	\N	\N	f	\N	2026-08-03 14:22:54.750221+00
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
8452b044-eeeb-48ac-90b6-b55341f19158	cc49de72-5ea8-402b-865a-c2fa66698151	Shi	BC:2B:02:3A:7F:7C	\N	8c2ec4ea-f9af-46f1-bcce-8a1460da6ec8	10.100.0.241	c40ad724-f25d-467f-a374-72016df6c393	2026-08-03 14:57:52.299404+00	t	2026-08-03 12:25:37.510174+00	2026-08-03 13:57:54.728338+00	16645706	23977648	1154554	2031436
\.


--
-- Data for Name: hotspot_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_packages (id, isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, created_at, updated_at) FROM stdin;
c40ad724-f25d-467f-a374-72016df6c393	cc49de72-5ea8-402b-865a-c2fa66698151	\N	1 Hour	\N	5.00	1	5	5	\N	1		t	2026-08-03 12:09:52.211897+00	2026-08-03 12:09:52.211897+00
\.


--
-- Data for Name: hotspot_sessions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_sessions (id, isp_id, voucher_id, nas_id, radius_session_id, mac_address, ip_address, nas_ip, bytes_downloaded, bytes_uploaded, session_time_seconds, status, started_at, ended_at, terminate_cause) FROM stdin;
\.


--
-- Data for Name: hotspot_vouchers; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_vouchers (id, isp_id, package_id, nas_id, code, batch_id, status, used_by_mac, used_by_ip, used_at, expires_at, bytes_downloaded, bytes_uploaded, time_used_seconds, is_paid, amount_paid, payment_method, payment_reference, created_at, updated_at, buyer_phone, sms_sent, expiry_sms_sent, payment_id, is_test, password, is_tv, tv_mac, created_by_isp, import_batch, purchased_by_mac) FROM stdin;
01da3d00-ab2e-4efe-8bd1-b3a1dd790c2a	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q3	\N	active	\N	\N	\N	2026-08-04 08:14:51+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.774787+00	2026-08-03 14:30:40.774787+00	0758317799	f	f	\N	f	3ea9yy	f	\N	t	imp_1785767440773	\N
134dc22d-993c-4ced-9f9d-b174e9a525fb	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q4	\N	active	\N	\N	\N	2026-08-04 00:36:15+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.787842+00	2026-08-03 14:30:40.787842+00	0712172518	f	f	\N	f	897553	f	\N	t	imp_1785767440773	\N
693b5187-adab-4c0c-abaf-41c5786eaefe	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q5	\N	active	\N	\N	\N	2026-08-03 18:07:28+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.797416+00	2026-08-03 14:30:40.797416+00	0715505550	f	f	\N	f	8yd85f	f	\N	t	imp_1785767440773	\N
287671f6-7996-4d99-bb90-a7e2df300bea	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q6	\N	active	\N	\N	\N	2026-08-06 15:51:06+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.80925+00	2026-08-03 14:30:40.80925+00	0704101226	f	f	\N	f	587x3a	f	\N	t	imp_1785767440773	\N
c8ef434a-01a6-4817-b9c8-6572c44ddaf7	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q7	\N	active	\N	\N	\N	2026-08-04 00:58:45+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.820704+00	2026-08-03 14:30:40.820704+00	0727134277	f	f	\N	f	ay36c8	f	\N	t	imp_1785767440773	\N
7d15e47f-b71a-4e38-8c8b-1fd0be7a9e35	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q8	\N	active	\N	\N	\N	2026-08-04 19:11:40+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.830224+00	2026-08-03 14:30:40.830224+00	0748296914	f	f	\N	f	39b6d4	f	\N	t	imp_1785767440773	\N
e00cf6a0-f7ea-43d6-bf3b-71273977773f	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q9	\N	active	\N	\N	\N	2026-08-04 09:36:10+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.840622+00	2026-08-03 14:30:40.840622+00	0710969039	f	f	\N	f	724258	f	\N	t	imp_1785767440773	\N
901141db-e0b8-4c9e-becf-e8bf8a7700dc	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q10	\N	active	\N	\N	\N	2026-08-03 15:00:06+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.852065+00	2026-08-03 14:30:40.852065+00	0799049396	f	f	\N	f	yxfx46	f	\N	t	imp_1785767440773	\N
8c2ec4ea-f9af-46f1-bcce-8a1460da6ec8	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q1	\N	active	BC:2B:02:3A:7F:7C	\N	\N	2026-08-03 14:57:52.299404+00	0	0	0	t	\N	\N	\N	2026-08-03 12:25:59.949218+00	2026-08-03 13:57:52.302766+00	254740258495	f	f	eea9258b-6fbd-40a1-b9cb-ad41bef67190	f	b9eye8	t	BC:2B:02:3A:7F:7C	f	\N	BC:2B:02:3A:7F:7C
3243652a-afb3-4b37-bed9-44d087b3db6b	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q11	\N	active	\N	\N	\N	2026-08-03 22:27:11+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.863445+00	2026-08-03 14:30:40.863445+00	0742518941	f	f	\N	f	4c4x63	f	\N	t	imp_1785767440773	\N
0cad288c-7a87-409d-8ee7-30980a55c694	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q12	\N	active	\N	\N	\N	2026-08-04 00:15:11+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.87318+00	2026-08-03 14:30:40.87318+00	0799512294	f	f	\N	f	x27ea7	f	\N	t	imp_1785767440773	\N
dc4cbf8a-64bc-424d-a095-d963133b1e29	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q13	\N	active	\N	\N	\N	2026-08-03 16:21:45+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.885472+00	2026-08-03 14:30:40.885472+00	0768327390	f	f	\N	f	f68x7e	f	\N	t	imp_1785767440773	\N
1cc2674d-0bc3-4281-8d30-03e5870280c5	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q14	\N	active	\N	\N	\N	2026-08-04 09:46:14+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.897394+00	2026-08-03 14:30:40.897394+00	0716522182	f	f	\N	f	c56f25	f	\N	t	imp_1785767440773	\N
29d41656-7ed0-4bde-aea7-3f729044ebf6	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q2	\N	active	AE:C1:5C:88:4A:7F	\N	\N	2026-08-03 14:59:11.694134+00	0	0	0	t	\N	\N	\N	2026-08-03 12:31:56.888416+00	2026-08-03 13:59:52.844463+00	254740258495	f	f	a66a2898-b21b-42a1-84ab-e908e006175d	f	fe8ba5	f	\N	f	\N	AE:C1:5C:88:4A:7F
9f03141b-6797-4070-b0ae-f20d605c7d2f	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q15	\N	active	\N	\N	\N	2026-08-03 22:22:07+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.908974+00	2026-08-03 14:30:40.908974+00	0742986898	f	f	\N	f	a29yed	f	\N	t	imp_1785767440773	\N
b5cb957c-14ab-4bf4-b7e0-6ba0a939a728	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q16	\N	active	\N	\N	\N	2026-08-03 16:40:38+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.919725+00	2026-08-03 14:30:40.919725+00	0722221132	f	f	\N	f	49y3y7	f	\N	t	imp_1785767440773	\N
584112c7-f6e6-4617-91c7-90cbb021ef30	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q17	\N	active	\N	\N	\N	2026-08-04 05:35:33+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.930867+00	2026-08-03 14:30:40.930867+00	0114876100	f	f	\N	f	497x8y	f	\N	t	imp_1785767440773	\N
0cb2d40c-53b8-4da9-b1a1-5204ae515dde	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q18	\N	active	\N	\N	\N	2026-08-04 11:34:28+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.941968+00	2026-08-03 14:30:40.941968+00	0706688720	f	f	\N	f	44b24b	f	\N	t	imp_1785767440773	\N
ee63e74a-0af3-482c-92b6-1c11271e9f6f	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q19	\N	active	\N	\N	\N	2026-08-03 20:18:56+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.953702+00	2026-08-03 14:30:40.953702+00	0143220441	f	f	\N	f	ffybcy	f	\N	t	imp_1785767440773	\N
c017e3dc-5fd7-427e-a6fb-8485857f212a	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q20	\N	active	\N	\N	\N	2026-08-03 17:12:47+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.963389+00	2026-08-03 14:30:40.963389+00	0143264640	f	f	\N	f	3d6x47	f	\N	t	imp_1785767440773	\N
c745bf95-1ab5-4c9c-a5b5-36a7ca47530e	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q21	\N	active	\N	\N	\N	2026-08-03 17:53:42+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.973497+00	2026-08-03 14:30:40.973497+00	0718778949	f	f	\N	f	2c2828	f	\N	t	imp_1785767440773	\N
a42983b5-ac7b-4bdb-804c-1689e76905e6	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q22	\N	active	\N	\N	\N	2026-08-03 18:34:47+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.983528+00	2026-08-03 14:30:40.983528+00	0797188355	f	f	\N	f	25c5e7	f	\N	t	imp_1785767440773	\N
73f7c08f-a18a-4809-ae63-c32cf0fd6a8e	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q23	\N	active	\N	\N	\N	2026-08-04 05:55:17+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:40.998827+00	2026-08-03 14:30:40.998827+00	0704714570	f	f	\N	f	63ceee	f	\N	t	imp_1785767440773	\N
90755695-e325-46b8-bdd6-fa07a9f42dee	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q24	\N	active	\N	\N	\N	2026-08-03 21:21:52+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.011701+00	2026-08-03 14:30:41.011701+00	0748894472	f	f	\N	f	367c7a	f	\N	t	imp_1785767440773	\N
43704884-8cc0-48e1-b071-0c51bcc31650	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q25	\N	active	\N	\N	\N	2026-08-04 10:35:17+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.021228+00	2026-08-03 14:30:41.021228+00	0143311188	f	f	\N	f	3d6c99	f	\N	t	imp_1785767440773	\N
28462842-2688-4183-9c82-c0bccd0a04b6	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q26	\N	active	\N	\N	\N	2026-08-04 01:48:07+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.032125+00	2026-08-03 14:30:41.032125+00	0118515781	f	f	\N	f	556d9c	f	\N	t	imp_1785767440773	\N
86350d3d-5741-4fae-bb9f-af60c64ad67d	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q27	\N	active	\N	\N	\N	2026-08-03 17:51:05+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.044364+00	2026-08-03 14:30:41.044364+00	0792979161	f	f	\N	f	xa5e2c	f	\N	t	imp_1785767440773	\N
1698820a-d80f-4822-b387-5849b0102338	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q28	\N	active	\N	\N	\N	2026-08-03 19:00:30+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.054379+00	2026-08-03 14:30:41.054379+00	0708482861	f	f	\N	f	9573c6	f	\N	t	imp_1785767440773	\N
cb2431e2-b4ab-478e-ab51-bb584a93f6d2	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q29	\N	active	\N	\N	\N	2026-08-04 02:17:02+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.063678+00	2026-08-03 14:30:41.063678+00	0721568776	f	f	\N	f	xxc3dy	f	\N	t	imp_1785767440773	\N
41777140-9c70-45be-9eaa-ae7f89b9bc6f	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q30	\N	active	\N	\N	\N	2026-08-04 03:23:58+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.077379+00	2026-08-03 14:30:41.077379+00	0722365763	f	f	\N	f	3x99ya	f	\N	t	imp_1785767440773	\N
480d2eac-9960-405e-8e50-0a5106dd2864	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q31	\N	active	\N	\N	\N	2026-08-03 15:07:08+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.086474+00	2026-08-03 14:30:41.086474+00	0724733806	f	f	\N	f	3737b6	f	\N	t	imp_1785767440773	\N
56cea5db-2a8a-40ec-8693-5f085b353f84	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q32	\N	active	\N	\N	\N	2026-08-03 18:40:28+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.097243+00	2026-08-03 14:30:41.097243+00	0725135792	f	f	\N	f	89efcb	f	\N	t	imp_1785767440773	\N
841e29c8-9b28-4c71-b554-31e31eeb51ea	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q33	\N	active	\N	\N	\N	2026-08-03 16:07:09+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.107879+00	2026-08-03 14:30:41.107879+00	0795487346	f	f	\N	f	c983d3	f	\N	t	imp_1785767440773	\N
2f7a42ce-956d-4433-80e9-ba0525544bed	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q34	\N	active	\N	\N	\N	2026-08-03 19:00:31+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.116989+00	2026-08-03 14:30:41.116989+00	0706556998	f	f	\N	f	3y75ey	f	\N	t	imp_1785767440773	\N
2f2224a8-bb22-49e1-a4ab-63a6978bc5cb	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q35	\N	active	\N	\N	\N	2026-08-03 22:42:55+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.127138+00	2026-08-03 14:30:41.127138+00	0740887780	f	f	\N	f	685fef	f	\N	t	imp_1785767440773	\N
05a1cfec-c905-45ac-bbb5-b4e6fde32fa8	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q36	\N	active	\N	\N	\N	2026-08-04 01:01:25+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.136859+00	2026-08-03 14:30:41.136859+00	0745718578	f	f	\N	f	b63bd8	f	\N	t	imp_1785767440773	\N
ebad990d-d58a-4d7f-b059-097a676bb865	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q37	\N	active	\N	\N	\N	2026-08-03 17:29:17+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.146026+00	2026-08-03 14:30:41.146026+00	0142084158	f	f	\N	f	c3a5c2	f	\N	t	imp_1785767440773	\N
006b904d-ca9b-45ea-b17d-dd2c87739699	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q38	\N	active	\N	\N	\N	2026-08-03 16:25:24+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.155918+00	2026-08-03 14:30:41.155918+00	0729295508	f	f	\N	f	6fy8yx	f	\N	t	imp_1785767440773	\N
2312caa7-2bcd-4a7b-8d47-787e0ec49855	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q39	\N	active	\N	\N	\N	2026-08-03 22:43:54+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.165993+00	2026-08-03 14:30:41.165993+00	0741086757	f	f	\N	f	4e325f	f	\N	t	imp_1785767440773	\N
d7f79ff8-0101-4b71-bbf0-78ae1287d4c3	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q40	\N	active	\N	\N	\N	2026-08-03 20:36:19+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.175785+00	2026-08-03 14:30:41.175785+00	0710581015	f	f	\N	f	b9d2ed	f	\N	t	imp_1785767440773	\N
7b2790fa-770d-47fd-8d86-68fff6785ca4	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q41	\N	active	\N	\N	\N	2026-08-03 17:50:29+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.185873+00	2026-08-03 14:30:41.185873+00	0720636750	f	f	\N	f	9542y4	f	\N	t	imp_1785767440773	\N
8296b84c-a0e7-47e4-9cae-279901d5fceb	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q42	\N	active	\N	\N	\N	2026-08-03 15:54:24+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.198324+00	2026-08-03 14:30:41.198324+00	0792813888	f	f	\N	f	7d36cb	f	\N	t	imp_1785767440773	\N
a1aee5cc-463d-42e7-be20-34b43bee9896	cc49de72-5ea8-402b-865a-c2fa66698151	c40ad724-f25d-467f-a374-72016df6c393	\N	Q43	\N	active	\N	\N	\N	2026-08-04 00:56:37+00	0	0	0	f	\N	\N	\N	2026-08-03 14:30:41.208662+00	2026-08-03 14:30:41.208662+00	0714649570	f	f	\N	f	5a64y2	f	\N	t	imp_1785767440773	\N
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

COPY public.isp_payment_methods (id, isp_id, method_type, label, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials, till_number, paybill_number, account_reference, bank_name, account_name, account_number, branch, forward_to_type, forward_to_number, forward_to_name, is_active, is_verified, is_default, created_at, updated_at, provider, environment) FROM stdin;
9f9050d2-eb73-46c8-bf4a-4422ef3768b1	cc49de72-5ea8-402b-865a-c2fa66698151	mpesa_stk	4322307	4322307	7V4yYILZxVLaYRalxSX7vLNKARpAItO9YwOzlA0pCCQ4KZQ0	b0eWBg6Cv0G558cMO6OhAbAKrJJ5wDvMAybO9axDEB1ZVastiVAAjh2HKwrz0VRw	3317f5d8845fbe32c8e8435e1b79934d36ae1c303f9383b5d8a35ac36d4720b6	f	f	\N	\N	\N	\N	\N	\N	\N	till	\N	\N	t	f	t	2026-08-03 12:44:01.433667+00	2026-08-03 12:44:01.433667+00	\N	production
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
e9b232f2-777f-403f-b22b-d659ba008e58	cc49de72-5ea8-402b-865a-c2fa66698151	payment	4.70	\N	4.70	IntaSend payment - RLIMSD71PGOZMQU	7d0c7d83-f4fa-4e9e-a78f-79696ac4264d	2026-08-03 12:17:25.085373+00
6173431d-bd05-4941-b118-7de44ff49279	cc49de72-5ea8-402b-865a-c2fa66698151	payment	4.85	\N	9.55	IntaSend payment - KQO6BL5	bf2228e1-201d-4d4d-89f1-1738b13ce3e7	2026-08-03 12:26:24.543708+00
5c20423a-f17c-4708-96ee-576445cc37c9	cc49de72-5ea8-402b-865a-c2fa66698151	payment	4.85	\N	14.40	IntaSend payment - 087LON2	1cfe897b-6b24-4761-917c-04515be7a3c1	2026-08-03 12:32:24.398506+00
83b72114-db45-49c0-878f-39739c1bca99	cc49de72-5ea8-402b-865a-c2fa66698151	payment	4.85	\N	19.25	IntaSend payment - 0XX7V27	6d05e9ce-df61-46d7-a85c-f8055c1fe213	2026-08-03 12:34:25.117877+00
67617f6d-b5e8-46b1-b153-bea981d1e9fe	cc49de72-5ea8-402b-865a-c2fa66698151	payment	5.00	\N	24.25	IntaSend payment - UH3131EOEO	eea9258b-6fbd-40a1-b9cb-ad41bef67190	2026-08-03 13:57:48.673726+00
\.


--
-- Data for Name: isps; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isps (id, company_name, owner_name, email, phone, password_hash, plan_type, status, county, town, address, api_key, api_secret, webhook_url, wallet_balance, commission_rate, pppoe_rate_per_user, total_earned, total_commission_paid, sms_gateway, sms_api_key, sms_sender_id, logo_url, timezone, currency, email_verified, email_verify_token, password_reset_token, password_reset_expires, trial_ends_at, last_login, created_at, updated_at, sms_username, sms_partner_id, sms_api_secret, support_number, hotspot_counter, subscription_started_at, license_expires_at, billing_window_start, license_status, billing_exempt, sms_balance, phone_verified, phone_verified_at, email_verified_at) FROM stdin;
cc49de72-5ea8-402b-865a-c2fa66698151	QuickCoin	peter	rumalinkenterprise@gmail.com	0704994652	$2a$12$3pXQxbTPfdzMadofrZqISOc27VBAdRh6JQWOe1JuIPKwSfE.qVYO.	both	active	Nairobi	Nairobi	\N	f633e136-e384-4b47-a382-40917bc5a52f	c9d5a2f76bb673f45331377ec9aadc22882e893ca61d106baa7501c55cdf9314	\N	\N	0.0300	32.25	35.00	0.90	rumalink			\N	Africa/Nairobi	KES	t	\N	\N	\N	2026-09-02 12:07:38.805301+00	2026-08-03 14:42:45.747112+00	2026-08-03 12:07:38.805301+00	2026-08-03 14:42:56.053473+00	\N	\N	\N	\N	2	\N	\N	\N	trial	f	38.0000	t	2026-08-03 12:09:26.601068+00	2026-08-03 12:08:18.380894+00
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
\.


--
-- Data for Name: mpesa_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.mpesa_transactions (id, isp_id, payment_id, checkout_request_id, merchant_request_id, result_code, result_desc, amount, mpesa_receipt, phone, transaction_date, status, raw_callback, created_at) FROM stdin;
5731cd6c-5ab5-4fee-9c4e-959cebb1da58	cc49de72-5ea8-402b-865a-c2fa66698151	7d0c7d83-f4fa-4e9e-a78f-79696ac4264d	RLIMSD71PGOZMQU	RLIMSD71PGOZMQU	\N	\N	5.00	\N	254740258495	\N	pending	\N	2026-08-03 12:16:52.779094+00
18b8205f-76a1-4b50-9ef9-7890a0040d30	cc49de72-5ea8-402b-865a-c2fa66698151	bf2228e1-201d-4d4d-89f1-1738b13ce3e7	RLIMSD7DF587JCN	RLIMSD7DF587JCN	\N	\N	5.00	\N	254740258495	\N	pending	\N	2026-08-03 12:25:59.939772+00
931b40e7-1017-4a9f-b547-3bc4875be697	cc49de72-5ea8-402b-865a-c2fa66698151	1cfe897b-6b24-4761-917c-04515be7a3c1	RLIMSD7L2SV7JYL	RLIMSD7L2SV7JYL	\N	\N	5.00	\N	254740258495	\N	pending	\N	2026-08-03 12:31:56.881233+00
51a7fe32-43ba-4d14-9b20-a15cdaf10c08	cc49de72-5ea8-402b-865a-c2fa66698151	6d05e9ce-df61-46d7-a85c-f8055c1fe213	RLIMSD7NUWAWZY3	RLIMSD7NUWAWZY3	\N	\N	5.00	\N	254740258495	\N	pending	\N	2026-08-03 12:34:06.609869+00
3a699a7b-1799-4aef-8ef6-60d6734b167f	cc49de72-5ea8-402b-865a-c2fa66698151	0aec030a-b9e2-4292-8612-016e370317ad	ws_CO_03082026154725318740258495	2225-4750-878c-a6bb3717aa6c10643665	\N	\N	5.00	UH3131EDLA	254740258495	2026-08-03 12:47:35.201725+00	completed	\N	2026-08-03 12:47:25.709321+00
80df147a-5fc8-4eb5-b2a8-38c5f104b965	cc49de72-5ea8-402b-865a-c2fa66698151	1d241f5d-0165-403a-a5c1-5372d281c00c	ws_CO_03082026155506235740258495	b5b5-496c-8349-40e9419e3f3c6189	\N	\N	5.00	UH3131E6O3	254740258495	2026-08-03 12:55:19.795843+00	completed	\N	2026-08-03 12:55:06.285353+00
018d62a3-b26b-4317-87c0-d15c14e0819c	cc49de72-5ea8-402b-865a-c2fa66698151	a2b23519-8ac1-4002-8ea7-70a498b1dbaf	ws_CO_03082026165032551740258495	e6f5-4b3d-93ed-bb868f4972bd9814517	\N	\N	5.00	UH3131EPNI	254740258495	2026-08-03 13:50:42.448147+00	completed	\N	2026-08-03 13:50:33.071773+00
1222adcd-cbb7-416c-b273-69123f6c99c1	cc49de72-5ea8-402b-865a-c2fa66698151	eea9258b-6fbd-40a1-b9cb-ad41bef67190	ws_CO_03082026165730440740258495	782d-4443-86ce-dad3d661539310761983	\N	\N	5.00	UH3131EOEO	254740258495	2026-08-03 13:57:52.301119+00	completed	\N	2026-08-03 13:57:30.418132+00
716cd97b-fe5a-405e-a170-9f39f8c71335	cc49de72-5ea8-402b-865a-c2fa66698151	a66a2898-b21b-42a1-84ab-e908e006175d	ws_CO_03082026165858062740258495	8eb7-4c9a-8f18-958f202f58a42129620	\N	\N	5.00	UH3131EK3L	254740258495	2026-08-03 13:59:11.696084+00	completed	\N	2026-08-03 13:58:58.7361+00
\.


--
-- Data for Name: nas; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas (id, nasname, shortname, type, ports, secret, server, community, description) FROM stdin;
1	10.8.0.2	DandoraPhase3	mikrotik	\N	RMLBB3D85BB6EF343CB	\N	\N	RumaLink auto-sync
\.


--
-- Data for Name: nas_devices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_devices (id, isp_id, name, description, nas_ip, nas_port, secret, provision_token, provision_url, is_provisioned, provisioned_at, mikrotik_identity, mikrotik_version, mikrotik_board, mikrotik_mac, wan_ip, is_online, last_seen, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port, created_at, updated_at, antishare_enabled, antishare_max_devices, bridged_ports, bridge_ports, hotspot_interface, pppoe_interface, gateway_ip, ip_pool_start, ip_pool_end, dns_primary, dns_secondary, hotspot_network, hotspot_gateway, hotspot_pool_start, hotspot_pool_end, mikrotik_api_user, mikrotik_api_password, remote_winbox_url, provision_step, cpu_load, memory_used_mb, memory_total_mb, disk_used_mb, disk_total_mb, uptime_seconds, wan_interface, available_interfaces, wireguard_private_key, wireguard_public_key, wireguard_ip, radius_secret, winbox_proxy_port, isp_link_status, isp_link_changed_at, isp_link_last_checked, isp_link_consecutive_failures, isp_link_notifications_enabled, multi_wan_mode, wan1_interface, wan1_gateway, wan1_ping_target, wan2_interface, wan2_gateway, wan2_ping_target, multi_wan_check_interval, multi_wan_fail_threshold, lb_weight_wan1, pcc_mode, multi_wan_applied_at, wan_quality_enabled, wan_quality_latency_ms, wan_quality_jitter_ms, wan_quality_loss_pct, wan_quality_trip_count, wan_quality_recover_count, wan_type, wan_pppoe_user, wan_pppoe_pass, wan_static_ip, wan_static_gw, wan_selected, wan_quality_min_mbps) FROM stdin;
dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	cc49de72-5ea8-402b-865a-c2fa66698151	DandoraPhase3	\N	\N	3799	RMLBB3D85BB6EF343CB	f451cc98-3e02-4754-8a83-fcf1b031ac16	https://rumalinkenterprise.online/api/provision/f451cc98-3e02-4754-8a83-fcf1b031ac16	t	2026-08-03 12:12:45.228893+00	MikroTik	7.19.6 (stable)	RB951Ui-2HnD	pending	\N	t	2026-08-03 14:52:38.756265+00	t	t	\N	\N	20001	2026-08-03 12:12:30.734508+00	2026-08-03 14:52:38.756265+00	f	1	["ether2", "ether3", "ether4", "wlan1"]	ether3,ether4,ether5	bridge1	ether1	192.168.88.1	192.168.88.10	192.168.88.254	8.8.8.8	8.8.4.4	10.100.0.0/24	10.100.0.1	10.100.0.10	10.100.0.250	rl_dc313eb1	255d8dc5-9dc	rumalinkenterprise.online:20001	configured	12	62	128	22	128	0	ether2	ether1,ether2,ether3,ether4,ether5	OEuJqZtWH7uck3Ta1JQMaN4teqvlawEtjQjM8I506Gk=	GOwRU+eEur391i+poE4qLNgLZ97UatTd13IhptYEjxM=	10.8.0.2	RMLBB3D85BB6EF343CB	\N	up	\N	2026-08-03 14:53:13.344+00	0	t	failover	\N	\N	8.8.8.8	\N	\N	1.1.1.1	10	3	50	both-addresses	2026-08-03 12:56:49.358022+00	t	150	60	2	4	4	pppoe	mikrotiktest2	mikrotik2541028	\N	\N	t	3
\.


--
-- Data for Name: nas_events; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_events (id, nas_id, isp_id, event_type, message, created_at) FROM stdin;
60dc244b-6ad0-4c2f-9953-f74f2ef3eb28	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	cc49de72-5ea8-402b-865a-c2fa66698151	provisioned	Config imported	2026-08-03 12:12:45.263233+00
9e5be2a7-ed3b-464f-8a1d-05e4ce8a1e2d	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	cc49de72-5ea8-402b-865a-c2fa66698151	wan_quality_degraded	⚠️ RumaLink: "DandoraPhase3" has switched to the BACKUP link — now on WAN2 (ether1). The main link is down or degraded. Your customers stay online on the backup; we will text you when the main link returns.	2026-08-03 13:36:39.829332+00
9452c06c-848b-4fd6-bf04-632f217d2c6b	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	cc49de72-5ea8-402b-865a-c2fa66698151	wan_quality_recovered	✅ RumaLink: "DandoraPhase3" is back on its MAIN link — WAN1 (ether2). The backup uplink is no longer carrying traffic.	2026-08-03 13:38:33.816403+00
\.


--
-- Data for Name: nas_wan_links; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_links (id, nas_id, "position", name, interface, gateway, ping_target, role, lb_weight, enabled, current_status, created_at, resolved_ip, resolved_gateway, last_checked_at, last_rtt, is_active, internet_ok, in_load_balance, is_failover, failover_priority, last_latency_ms, last_jitter_ms, last_loss_pct, quality_state, consec_degraded, consec_good, quality_parked, probe_verdict, probe_stage, dns_ms, connect_ms, fetch_ms, throughput_kbps, last_fetch_at, consec_fetch_fail, sample_history, consec_slow, bytes_carried, bytes_since, last_tx_bytes, last_rx_bytes, bytes_month_start, in_pool, last_mbps, tp_checked_at) FROM stdin;
ef5c96fe-2339-495b-9b84-4c6dff6aa453	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	2	Link 2	ether1	\N	8.8.8.8	failover_backup	50	t	standby	2026-08-03 12:56:22.553655+00	192.168.8.6/24	192.168.8.1	2026-08-03 14:53:16.191528+00	48ms143us	f	t	f	t	2	\N	\N	\N	good	0	0	f	good	complete	\N	\N	2234	\N	2026-08-03 14:53:15.921854+00	0		0	73538283	2026-08-03 12:56:22.553655+00	19113882	87851119	\N	t	\N	\N
b14f80be-2257-4741-8dc5-1f410353f4a0	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	1	Link 1	ether2	\N	8.8.8.8	failover_primary	50	t	online	2026-08-03 12:56:22.551683+00	172.31.7.216/32	rl-wan-pppoe	2026-08-03 14:53:16.189746+00	8ms31us	t	t	f	t	1	7.951	0.2	0	good	0	198	f	good	complete	\N	\N	1200	\N	2026-08-03 14:52:59.801094+00	0	0000000000	0	585136567	2026-08-03 12:56:22.551683+00	211897264	473549142	\N	t	\N	2026-08-03 14:52:10.165615+00
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
ff757dc9-e723-4030-b610-3fedb77e3fce	\N	\N	info	New ISP Registered	QuickCoin has registered on the platform (both plan)	f	\N	2026-08-03 12:07:39.895195+00
925886dd-b877-4df8-9947-3285adacae92	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	MikroTik Connected	"DandoraPhase3" checked in. Run the import command to apply config.	f	/isp/dashboard.html	2026-08-03 12:12:30.828605+00
ad88294f-aacf-4903-a75d-7e21a4fed435	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	MikroTik Configured	"DandoraPhase3" pulled and imported its config.	f	/isp/dashboard.html	2026-08-03 12:12:45.261266+00
0e24f40d-72cb-459e-b8e9-4efed1937bb5	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	Payment Received	KES 4.70 credited to your wallet (IntaSend).	f	\N	2026-08-03 12:17:25.087233+00
73101e26-e164-434a-b19f-57f1eda710b4	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	Payment Received	KES 4.85 credited to your wallet (IntaSend).	f	\N	2026-08-03 12:26:24.545491+00
501a4127-3f18-4ae2-a1e6-91c04d966881	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	Payment Received	KES 4.85 credited to your wallet (IntaSend).	f	\N	2026-08-03 12:32:24.40026+00
09903905-8c56-4525-b7bc-a26915c967e4	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	Payment Received	KES 4.85 credited to your wallet (IntaSend).	f	\N	2026-08-03 12:34:25.119473+00
923a45f2-40a4-4d90-b36c-d62338c0d14a	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-03 13:57:48.675468+00
4ae8c7dd-d227-4383-889f-9184b7a5c552	cc49de72-5ea8-402b-865a-c2fa66698151	\N	success	Payment Received	KES null credited to your wallet (IntaSend).	f	\N	2026-08-03 14:22:54.756248+00
\.


--
-- Data for Name: payment_provider_configs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.payment_provider_configs (id, provider, label, merchant_code, consumer_key, consumer_secret, api_key, private_key, public_key, base_url, is_sandbox, is_active, created_at, updated_at) FROM stdin;
a4c097d0-d422-422a-b556-db68de15d422	jenga	\N	1587205221	\N	9qFZ7w5zKti9nXVlK8Zl28Cr3Z14oD	7bg07O+pMst83rwQavCCtLKQiA693tOKJeNS3VMzRRG0CI1FtNbdC4U9ULNu2V0ePAU/P1V1oOBrbCeyUsv2Og==	-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDZgGWIQcLQArlq\nVzrF4SV3KoA9QMChkSzbwruSL5k08wICvVyeJDGWQrhuViMmD8zts7Pi4crINnj/\n1A3Xu1j50CrLUl8g0LkutaUJmlBFLromrWItuzG44fNJcAfa6+NS3bsFXONFz9Lw\npPraasG+01XH5SlOC9eO+1sArs3Yt+s/GiDlYvbX28ALMjfX6tUV1vzSjBsvacRS\ndLCXCGZrM/K5pYKjyd3UgigRUsnWmgzNVsV3buXZqh936UcHvT48YHo0TuqYsq7d\nsV0OchtliY4P29eKHLt4gpP5b1TyWl4Mt9inQOwT8UrU6AHrEiECBRTfkQXS5JPi\nT2BSmzL/AgMBAAECggEAEdBpQHlsxjjnswG1YusRJ8sq2Rl6TYfEiue03jQya63l\nm1zWftTyQywJ/m6x27AanEA5YQ4WQkMeTCUA0NhCFHMYz8tacEEekbVRJAUbQvdU\nFs8UbGNzHwEeoIRIMgWOk/hslQ1dFGUBRWV11R+ktVQkDmApSGbbsmHJVWtImWtp\nD7Rf+7XE6Zel+IbAFnHhICnaUOxoSWE3nNmOhYyRBniL+2r4v7LgRonZLWrcfAJ6\nxz9kLzvKcFS4xRMY1aEcfV+g5yu8rVWJlp4ImsL/qFJXfezhW5lN6lI2DxUv/3DQ\ntLTDQktPl4nX2MdZb+RTocPN9yIw9ZOlV9QueOtT4QKBgQDsfAA9sgQVNXsC46+s\nUuEpDRRVyj5iSCSBOZnILwMq+I1ZLWbZE4rhyK8XuEjkAApRbu8gxbEwB/1rHLnO\nl/9QIogveDJBOJoXT0N2KiI1EAJJ1byarvqKYpJ9qt4rXKSHHsuXK05K+jtvngh0\n3IZTEqQ15nx4KUNXK+RSyc1EHwKBgQDrc1ysEZK2dIXzUfNduuwrtJpWvPjOEyXL\nedNIe6MShpeo8KAyCtCmFY6yFbkuwIiu+hbqy+zunEZnV5wtCurbDaAKHuys/LG8\npiyoRE2SSMjxhlTcAejV+iacQIicsJMxgZ1CYgJYPiQhzGi4G2apBXaQoFraS/dH\nUNw2lpU1IQKBgEoxSR4SCIfi5HnulwHYar2nVdbogZPyEEnemWmdnj/QBQCSZu75\n25uki5JEhdHKVXJg/HLqswFfsFj3hS/UrgwlGVbTPekKagWgH4kmBN9i62TgwrBA\n72eVL2Jvxg4SnaequLLvqjuJsDX/faW0Pgw4D/69FhXY1EC4C4URvO1/AoGAbpL9\nAKo4FovepIjmHCy+4T+uA/I3fsArTcXm3fGCgh7HdsWa1iWSG42gOC5Pi49MIbC9\ntoMSwHSP89SHOfgYl8tsT5R6XjtGVWxNKLD7JSodhKArli8nY+ZY36THA59BYUyX\nyCczJrH4Ug8nVt83dUVli0JjqIVomgt1gAV0CUECgYEAnbNrjveCgrQO5EjjEJdQ\nIT609vwNH8C1ejhBKjnTUN5+mLeiufDKt86Bn0a0qftpyZVO2DGdgHb10+reZJdM\n7l06KDwHPej5b2XemSITbJSZy2oLeI4qhBa/dc61NhrgtXlFp/zfSFcGVkEduVmu\nTXA8NtHeQFrZ0mdh8TnNX6Y=\n-----END PRIVATE KEY-----	\N	https://uat.finserve.africa	t	t	2026-06-22 09:55:15.524141+00	2026-06-22 10:01:08.802393+00
216d93ea-0023-436c-9f8d-f5050ebd40ec	intasend	IntaSend (Admin)	\N	\N	\N	ISPubKey_live_f91fd764-5270-421a-8941-47ba26937add	ISSecretKey_live_ba853033-539b-4373-a155-a19614d63974	\N	https://payment.intasend.com/api/v1/	f	t	2026-07-10 12:08:52.135529+00	2026-08-03 08:32:19.379548+00
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.payments (id, isp_id, subscriber_id, voucher_id, amount, currency, payment_method, payment_gateway, transaction_id, gateway_reference, phone_number, commission_amount, commission_rate, net_amount, status, failure_reason, description, metadata, paid_at, created_at, updated_at, used_admin_credentials, forwarded_to, forwarded_at, forward_status, mpesa_phone, mpesa_amount, mpesa_name, clearing_status, cleared_at, intasend_invoice, mpesa_receipt, voucher_activated_at) FROM stdin;
eea9258b-6fbd-40a1-b9cb-ad41bef67190	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa	mpesa_stk	UH3131EOEO	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_purchase_sms": "sent"}	2026-08-03 13:57:52.299404+00	2026-08-03 13:57:29.380339+00	2026-08-03 13:57:29.380339+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-03 13:57:48.667135+00
7d0c7d83-f4fa-4e9e-a78f-79696ac4264d	cc49de72-5ea8-402b-865a-c2fa66698151	6ac05a64-6230-4f23-9662-2bfea2654923	\N	5.00	KES	mpesa_stk	intasend	\N	RLIMSD71PGOZMQU	254740258495	0.30	0.0300	4.70	paid	\N	PPPoE - 10Mbps	{"gross": 5, "rl_consumed": "2026-08-03 12:17:23.925706+00", "intasend_fee": 0.15, "intasend_state": "PENDING", "rl_pppoe_healed": "yes", "intasend_invoice": "0WDOZJD", "platform_commission": 0.15}	2026-08-03 12:17:23.922768+00	2026-08-03 12:16:52.776432+00	2026-08-03 12:17:23.918301+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
0aec030a-b9e2-4292-8612-016e370317ad	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa	mpesa_stk	UH3131EDLA	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_purchase_sms": "sent"}	2026-08-03 12:47:35.199899+00	2026-08-03 12:47:24.038294+00	2026-08-03 12:47:24.038294+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-03 12:47:35.212869+00
1d241f5d-0165-403a-a5c1-5372d281c00c	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa	mpesa_stk	UH3131E6O3	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_purchase_sms": "sent"}	2026-08-03 12:55:19.794237+00	2026-08-03 12:55:04.498937+00	2026-08-03 12:55:04.498937+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-03 12:55:19.805496+00
6d05e9ce-df61-46d7-a85c-f8055c1fe213	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa_stk	intasend	0XX7V27	RLIMSD7NUWAWZY3	254740258495	0.15	0.0300	4.85	paid	\N	Hotspot - 1 Hour	{"mac": "AE:C1:5C:88:4A:7F", "gross": 5, "intasend_fee": 0.15, "intasend_state": "PENDING", "rl_purchase_sms": "sent", "intasend_invoice": "0XX7V27", "platform_commission": 0.15}	2026-08-03 12:34:25.097075+00	2026-08-03 12:34:06.250357+00	2026-08-03 14:52:58.526009+00	t	\N	\N	\N	\N	\N	\N	CLEARING	\N	0XX7V27	\N	2026-08-03 12:34:25.112268+00
a66a2898-b21b-42a1-84ab-e908e006175d	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa	mpesa_stk	UH3131EK3L	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_purchase_sms": "sent"}	2026-08-03 13:59:11.694134+00	2026-08-03 13:58:57.682164+00	2026-08-03 13:58:57.682164+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-03 13:59:11.707512+00
1cfe897b-6b24-4761-917c-04515be7a3c1	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa_stk	intasend	087LON2	RLIMSD7L2SV7JYL	254740258495	0.15	0.0300	4.85	paid	\N	Hotspot - 1 Hour	{"mac": "AE:C1:5C:88:4A:7F", "gross": 5, "intasend_fee": 0.15, "intasend_state": "PENDING", "rl_purchase_sms": "sent", "intasend_invoice": "087LON2", "platform_commission": 0.15}	2026-08-03 12:32:24.367227+00	2026-08-03 12:31:56.5277+00	2026-08-03 14:52:58.777762+00	t	\N	\N	\N	\N	\N	\N	CLEARING	\N	087LON2	\N	2026-08-03 12:32:24.391245+00
a2b23519-8ac1-4002-8ea7-70a498b1dbaf	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa	mpesa_stk	UH3131EPNI	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_purchase_sms": "sent"}	2026-08-03 13:50:42.446378+00	2026-08-03 13:50:32.011054+00	2026-08-03 13:50:32.011054+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-03 13:50:43.635233+00
bd3cdd19-2faf-44b8-be5b-bff1a2bf5bec	cc49de72-5ea8-402b-865a-c2fa66698151	6ac05a64-6230-4f23-9662-2bfea2654923	\N	10.00	KES	mpesa	mpesa_stk	UH3131ENLO	\N	254740258495	0.00	0.0300	\N	paid	\N	PPPoE - 15Mbps	{"rl_consumed": "2026-08-03 14:22:52.487604+00", "rl_renewal_sms": "sent", "rl_pppoe_healed": "yes", "switch_package_id": "fe67f13b-76f7-4bcc-a3dd-5790e3d5273d"}	2026-08-03 14:22:52.479109+00	2026-08-03 14:22:40.227612+00	2026-08-03 14:22:40.227612+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bf2228e1-201d-4d4d-89f1-1738b13ce3e7	cc49de72-5ea8-402b-865a-c2fa66698151	\N	\N	5.00	KES	mpesa_stk	intasend	KQO6BL5	RLIMSD7DF587JCN	254740258495	0.15	0.0300	4.85	paid	\N	Hotspot - 1 Hour	{"mac": "BC:2B:02:3A:7F:7C", "gross": 5, "is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "intasend_fee": 0.15, "intasend_state": "PENDING", "rl_purchase_sms": "sent", "intasend_invoice": "KQO6BL5", "platform_commission": 0.15}	2026-08-03 12:26:24.512252+00	2026-08-03 12:25:59.276945+00	2026-08-03 14:52:59.039024+00	t	\N	\N	\N	\N	\N	\N	CLEARING	\N	KQO6BL5	\N	2026-08-03 12:26:24.5374+00
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
bb1b37bc-718a-48d0-b613-00038ac9c71e	cc49de72-5ea8-402b-865a-c2fa66698151	10Mbps	\N	5.00	monthly	10	10	\N	\N	\N	\N			t	2026-08-03 12:10:18.203408+00	2026-08-03 12:10:18.203408+00
fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	cc49de72-5ea8-402b-865a-c2fa66698151	15Mbps		10.00	monthly	15	15	\N	\N	\N	\N			t	2026-08-03 14:22:13.67107+00	2026-08-03 14:22:25.236014+00
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
8b341db9-2276-4310-8827-ff39826ba109	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	Martin	CHANGE_ME_2e1b0a	Martin Wanjitu	0705449840	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-07 21:31:26+00	\N	\N	2026-08-03 14:30:40.806713+00	2026-08-03 14:30:40.806713+00	\N	f	f	imp_1785767440773
b3d66915-2459-4ad1-98ba-2d5c5a529140	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	Pauline	CHANGE_ME_6f6c56	Pauline Njeri	0705519292	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-09 18:02:00+00	\N	\N	2026-08-03 14:30:40.850413+00	2026-08-03 14:30:40.850413+00	\N	f	f	imp_1785767440773
e268e141-eaaf-4b8a-b7ad-20a8999e0f5d	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	Hannah	CHANGE_ME_5e8ac7	Hannah Wambui	0727509143	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-23 14:31:55+00	\N	\N	2026-08-03 14:30:40.861762+00	2026-08-03 14:30:40.861762+00	\N	f	f	imp_1785767440773
30578958-0a14-4926-97cc-a4456b35782a	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	skita	CHANGE_ME_d3d52c	Skita Njiru	0704252101	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-09 19:34:18+00	\N	\N	2026-08-03 14:30:40.882419+00	2026-08-03 14:30:40.882419+00	\N	f	f	imp_1785767440773
7f4ab094-130b-4881-8d1c-c50ab5d4345e	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	miriam	CHANGE_ME_cb51fc	Miriam Wanjiku	0724145513	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-08 15:35:45+00	\N	\N	2026-08-03 14:30:40.883904+00	2026-08-03 14:30:40.883904+00	\N	f	f	imp_1785767440773
6a4adbb0-9442-4302-934d-66a46315cb40	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	shadrack	CHANGE_ME_f69ef5	Shadrack Wanjohi	0701771261	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-14 16:28:13+00	\N	\N	2026-08-03 14:30:40.894355+00	2026-08-03 14:30:40.894355+00	\N	f	f	imp_1785767440773
4d907586-de88-4fe9-8423-2a9f8203bba6	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	lucia	CHANGE_ME_5af748	Lucia Mumbua	0720564724	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-15 09:56:35+00	\N	\N	2026-08-03 14:30:40.895803+00	2026-08-03 14:30:40.895803+00	\N	f	f	imp_1785767440773
8c871200-248a-4537-b2f4-603b9c76f2e2	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	andrew	CHANGE_ME_dd9246	Andrew Mutahi	0721779330	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-16 19:19:52+00	\N	\N	2026-08-03 14:30:40.907521+00	2026-08-03 14:30:40.907521+00	\N	f	f	imp_1785767440773
bc374773-849c-4d72-9dee-97028cb2a9cb	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	bena	CHANGE_ME_1bb917	bena	\N	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-10-20 08:54:00+00	\N	\N	2026-08-03 14:30:40.918264+00	2026-08-03 14:30:40.918264+00	\N	f	f	imp_1785767440773
b19a1384-ca56-4b57-bbff-27059933a907	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	susan	CHANGE_ME_b8c3b0	Susan Kahugu	0723544891	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-07 20:28:27+00	\N	\N	2026-08-03 14:30:40.929408+00	2026-08-03 14:30:40.929408+00	\N	f	f	imp_1785767440773
6ac05a64-6230-4f23-9662-2bfea2654923	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	benard	$2a$10$bnUV8yJynXb/4xkILoMKVeg53Slk9eSWwIuV0c6M8.IzEFsQwEB.6	benard	0740258495				Nairobi	\N	\N	\N	\N	expired	0.00	2026-08-03 14:28:00+00	2026-08-03	\N	2026-08-03 12:10:53.318829+00	2026-08-03 14:28:00.16195+00	2026-08-03 14:22:54.958648+00	f	f	\N
e8e2dc52-4f76-4ba9-9fb4-bb897b08054f	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	george	CHANGE_ME_ca6d45	George Maina	0722224565	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-07 19:04:31+00	\N	\N	2026-08-03 14:30:40.940499+00	2026-08-03 14:30:40.940499+00	\N	f	f	imp_1785767440773
f3cce12f-8e05-49fa-9bf7-1e3598e1f53b	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	margaret	CHANGE_ME_a00c8e	Margaret Mwigai	0759704517	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-10 19:22:15+00	\N	\N	2026-08-03 14:30:40.995685+00	2026-08-03 14:30:40.995685+00	\N	f	f	imp_1785767440773
e5bf8c8f-7f4b-4c92-abae-6e71c4284376	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	serah	CHANGE_ME_83df8c	Serah Githiri	0742311552	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-17 14:21:51+00	\N	\N	2026-08-03 14:30:40.997323+00	2026-08-03 14:30:40.997323+00	\N	f	f	imp_1785767440773
9b6b374f-861b-4ca6-a73a-c5006962ee5d	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	joseph	CHANGE_ME_fce549	Joseph Kariuki	0722388620	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-20 16:45:24+00	\N	\N	2026-08-03 14:30:41.008769+00	2026-08-03 14:30:41.008769+00	\N	f	f	imp_1785767440773
888b6803-dd7e-492d-8762-1aac1eb41689	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	timothy	CHANGE_ME_68099e	Timothy Wanderi	0113263086	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-22 18:19:00+00	\N	\N	2026-08-03 14:30:41.010224+00	2026-08-03 14:30:41.010224+00	\N	f	f	imp_1785767440773
69f0ac07-08b9-47c4-9bb0-6af5bd7da4b2	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	irene	CHANGE_ME_46c3e9	Irene Wangari	0714849306	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-04 12:58:12+00	\N	\N	2026-08-03 14:30:41.030541+00	2026-08-03 14:30:41.030541+00	\N	f	f	imp_1785767440773
ee920833-4b77-4139-ab53-4610626e5256	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	orpha	CHANGE_ME_ffb237	Orpha Mutheu	0748723968	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-26 10:29:50+00	\N	\N	2026-08-03 14:30:41.072919+00	2026-08-03 14:30:41.072919+00	\N	f	f	imp_1785767440773
01b29c03-c94b-42a7-bffa-78a1ecccdfdc	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	albert2	CHANGE_ME_eaf982	Albert2 Macharia	0735947478	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-24 16:55:08+00	\N	\N	2026-08-03 14:30:41.074363+00	2026-08-03 14:30:41.074363+00	\N	f	f	imp_1785767440773
5c5179fa-4af1-4ee9-bf0c-86c4a3860425	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	angela	CHANGE_ME_4034f0	Angela Odhiambo	0720523121	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-26 14:49:58+00	\N	\N	2026-08-03 14:30:41.075751+00	2026-08-03 14:30:41.075751+00	\N	f	f	imp_1785767440773
06347ff9-c10f-4f5d-863e-17437c003f1f	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	daniel	CHANGE_ME_87b573	Daniel	0725707768	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-13 19:10:00+00	\N	\N	2026-08-03 14:30:41.0957+00	2026-08-03 14:30:41.0957+00	\N	f	f	imp_1785767440773
93b644e9-2dbc-4c19-b151-74d982f9b30c	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	mikrotiktest2	CHANGE_ME_e1d75a	mikrotiktest2	01171959421	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-31 18:53:00+00	\N	\N	2026-08-03 14:30:41.1064+00	2026-08-03 14:30:41.1064+00	\N	f	f	imp_1785767440773
4ecf0675-80d3-4506-ae58-ef40b8654bf9	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	daniel2	CHANGE_ME_c3d5ec	daniel2	07485236481	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-27 18:01:00+00	\N	\N	2026-08-03 14:30:41.196803+00	2026-08-03 14:30:41.196803+00	\N	f	f	imp_1785767440773
a4338f35-330e-42f8-b286-4eb9ddaee0d6	cc49de72-5ea8-402b-865a-c2fa66698151	fe67f13b-76f7-4bcc-a3dd-5790e3d5273d	\N	Jackline	CHANGE_ME_068bdc	Jackline Mwangangi	0713773260	\N	\N	\N	\N	\N	\N	\N	\N	expired	0.00	2026-08-03 14:35:00+00	\N	\N	2026-08-03 14:30:40.819115+00	2026-08-03 14:35:00.447233+00	\N	f	f	imp_1785767440773
\.


--
-- Data for Name: radacct; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radacct (radacctid, acctsessionid, acctuniqueid, username, nasipaddress, nasportid, nasporttype, acctstarttime, acctstoptime, acctinterval, acctsessiontime, acctauthentic, connectinfo_start, connectinfo_stop, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, acctterminatecause, servicetype, framedprotocol, framedipaddress, acctstart_delay, acctdelivery_date, realm, acctupdatetime, framedipv6address, framedipv6prefix, framedinterfaceid, delegatedipv6prefix) FROM stdin;
1	81000000	37aa197b1a997e8e04e61f0ddd6d4acc	benard	10.8.0.2	bridge-hotspot	Ethernet	2025-09-11 09:10:16+00	2025-09-11 09:12:02+00	\N	106	RADIUS			612033	4633709	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 12:14:18.207927+00	\N	2025-09-11 09:12:02+00	\N	\N	\N	\N
2	81000001	81f7b6435e94c090ef25bb7a755a095a	benard	10.8.0.2	bridge-hotspot	Ethernet	2025-09-11 09:12:07+00	2025-09-11 09:12:44+00	\N	37	RADIUS			114714	93022	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 12:16:09.298696+00	\N	2025-09-11 09:12:44+00	\N	\N	\N	\N
3	81000002	abb5d0b5b65979f824ff31c9194805ca	benard	10.8.0.2	bridge-hotspot	Ethernet	2025-09-11 09:12:50+00	2025-09-11 09:13:23+00	\N	34	RADIUS			23786	25792	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 12:16:52.002083+00	\N	2025-09-11 09:13:23+00	\N	\N	\N	\N
4	81000003	d17671633933e8d04e7d3325328f730f	benard	10.8.0.2	bridge-hotspot	Ethernet	2025-09-11 09:13:27+00	2026-08-03 12:20:44+00	\N	196	RADIUS			17563037	29045567	rumalink	50:0F:F5:36:A7:50	Lost-Carrier	Framed-User	PPP	100.64.0.254	\N	2026-08-03 12:17:29.790114+00	\N	2026-08-03 12:20:44+00	\N	\N	\N	\N
5	80000009	c648c0c3e574d21ea6994551b57aea1b	Q2@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 12:32:28+00	2026-08-03 12:33:42+00	\N	74				724157	5731474	rl-hotspot	AE:C1:5C:88:4A:7F	Admin-Reset			10.100.0.242	\N	2026-08-03 12:32:28.75162+00	\N	2026-08-03 12:33:42+00	\N	\N	\N	\N
13	8000001d	566017933ffdaae8c3ca82e09fcb4315	Q2@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 13:59:15+00	2026-08-03 14:15:35+00	120	980				8203655	34763720	rl-hotspot	AE:C1:5C:88:4A:7F	Lost-Service			10.100.0.239	\N	2026-08-03 13:59:15.842684+00	\N	2026-08-03 14:15:35+00	\N	\N	\N	\N
11	80000016	5911c62ef61e0aa61cb3f1ef1de15734	Q2@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 13:31:13+00	2026-08-03 13:52:15+00	120	1262				9033076	81153092	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.237	\N	2026-08-03 13:31:13.307256+00	\N	2026-08-03 13:52:15+00	\N	\N	\N	\N
15	81000005	367b1f311c0a130bfc73583159323c64	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-03 14:15:02+00	2026-08-03 14:19:12+00	\N	250	RADIUS			18678	21160	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 14:15:02.429737+00	\N	2026-08-03 14:19:12+00	\N	\N	\N	\N
6	8000000b	5220f1c8cb01da84d8522bf9ffa122c7	Q2@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 12:34:29+00	2026-08-03 12:46:03+00	120	694				580460	1523436	rl-hotspot	AE:C1:5C:88:4A:7F	Admin-Reset			10.100.0.242	\N	2026-08-03 12:34:29.456506+00	\N	2026-08-03 12:46:03+00	\N	\N	\N	\N
12	80000019	4f745c955f875d4e5e9d065de89f348a	Q1@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 13:50:47+00	2026-08-03 13:55:57+00	120	310				191781	188692	rl-hotspot	AE:C1:5C:88:4A:7F	Admin-Reset			10.100.0.239	\N	2026-08-03 13:50:47.805079+00	\N	2026-08-03 13:55:57+00	\N	\N	\N	\N
7	8000000f	b99baf2db25d1565bfa31fb2111e1a91	Q1@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 12:47:40+00	2026-08-03 12:52:31+00	119	291				487757	3307251	rl-hotspot	AE:C1:5C:88:4A:7F	Admin-Reset			10.100.0.242	\N	2026-08-03 12:47:40.295243+00	\N	2026-08-03 12:52:31+00	\N	\N	\N	\N
8	80000010	fdce9be7459cc6ba22f31a147550e6a9	Q1@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 12:52:49+00	2026-08-03 12:54:02+00	\N	73				38015	64092	rl-hotspot	AE:C1:5C:88:4A:7F	Admin-Reset			10.100.0.242	\N	2026-08-03 12:52:49.142178+00	\N	2026-08-03 12:54:02+00	\N	\N	\N	\N
9	80000012	6851ab95d61c187b52edb474d13e3b46	Q2@cc49de72	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 12:55:23+00	2026-08-03 13:23:17+00	120	1674				38833620	189847874	rl-hotspot	AE:C1:5C:88:4A:7F	Lost-Service			10.100.0.242	\N	2026-08-03 12:55:23.42036+00	\N	2026-08-03 13:23:17+00	\N	\N	\N	\N
16	81000006	683a8107f9e6e3d4075942e6ee1dc14f	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-03 14:19:16+00	2026-08-03 14:22:54+00	\N	218	RADIUS			152190	144798	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 14:19:17.05796+00	\N	2026-08-03 14:22:54+00	\N	\N	\N	\N
10	80000015	ef5db2d4d5fdeac6936c26a0a6d6c535	AE:C1:5C:88:4A:7F	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-03 13:25:48+00	2026-08-03 13:28:08+00	121	139				61100	124029	rl-hotspot	AE:C1:5C:88:4A:7F	Lost-Service			10.100.0.239	\N	2026-08-03 13:25:49.00612+00	\N	2026-08-03 13:28:08+00	\N	\N	\N	\N
17	81000007	8e6b6f95b0e247a3a753f2b51ddfe00b	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-03 14:22:59+00	2026-08-03 14:28:03+00	300	304	RADIUS			19701019	14349648	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 14:22:59.685521+00	\N	2026-08-03 14:28:03+00	\N	\N	\N	\N
18	81000008	5ad5a36dc6b6b3413fe18f3ce903428d	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-03 14:28:08+00	2026-08-03 14:28:29+00	\N	21	RADIUS			2230	2624	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 14:28:08.44815+00	\N	2026-08-03 14:28:29+00	\N	\N	\N	\N
14	81000004	3aae456f62c59d80cc9807ef8baca7a8	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-03 14:14:34+00	2026-08-03 14:14:56+00	\N	22	RADIUS			1638	1880	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 14:14:34.590377+00	\N	2026-08-03 14:14:56+00	\N	\N	\N	\N
19	81000009	77691a82ec8cd3e27f737c82de0e1f6f	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-03 14:28:34+00	2026-08-03 14:28:41+00	\N	8	RADIUS			222	296	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-03 14:28:34.306814+00	\N	2026-08-03 14:28:41+00	\N	\N	\N	\N
20	8100000a	bf9a84a8808e84c2cef64d09e24f8852	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-03 14:28:46+00	\N	300	1200	RADIUS		\N	165330	183353	rumalink	50:0F:F5:36:A7:50	\N	Framed-User	PPP	100.64.0.254	\N	2026-08-03 14:28:46.922764+00	\N	2026-08-03 14:48:46+00	\N	\N	\N	\N
\.


--
-- Data for Name: radcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radcheck (id, username, attribute, op, value) FROM stdin;
1	benard	Cleartext-Password	:=	benard2541028
2	benard	NT-Password	:=	0B340A7005F4C900BF15E1D362239383
19	Q1@cc49de72	Cleartext-Password	:=	b9eye8
20	Q2@cc49de72	Cleartext-Password	:=	fe8ba5
22	AE:C1:5C:88:4A:7F	Cleartext-Password	:=	RLMACAUTH
65	Q3@cc49de72	Cleartext-Password	:=	3ea9yy
66	Q4@cc49de72	Cleartext-Password	:=	897553
67	Q5@cc49de72	Cleartext-Password	:=	8yd85f
68	Q6@cc49de72	Cleartext-Password	:=	587x3a
69	Q7@cc49de72	Cleartext-Password	:=	ay36c8
70	Q8@cc49de72	Cleartext-Password	:=	39b6d4
71	Q9@cc49de72	Cleartext-Password	:=	724258
72	Q10@cc49de72	Cleartext-Password	:=	yxfx46
73	Q11@cc49de72	Cleartext-Password	:=	4c4x63
74	Q12@cc49de72	Cleartext-Password	:=	x27ea7
75	Q13@cc49de72	Cleartext-Password	:=	f68x7e
76	Q14@cc49de72	Cleartext-Password	:=	c56f25
77	Q15@cc49de72	Cleartext-Password	:=	a29yed
78	Q16@cc49de72	Cleartext-Password	:=	49y3y7
79	Q17@cc49de72	Cleartext-Password	:=	497x8y
80	Q18@cc49de72	Cleartext-Password	:=	44b24b
81	Q19@cc49de72	Cleartext-Password	:=	ffybcy
82	Q20@cc49de72	Cleartext-Password	:=	3d6x47
83	Q21@cc49de72	Cleartext-Password	:=	2c2828
84	Q22@cc49de72	Cleartext-Password	:=	25c5e7
85	Q23@cc49de72	Cleartext-Password	:=	63ceee
86	Q24@cc49de72	Cleartext-Password	:=	367c7a
87	Q25@cc49de72	Cleartext-Password	:=	3d6c99
88	Q26@cc49de72	Cleartext-Password	:=	556d9c
89	Q27@cc49de72	Cleartext-Password	:=	xa5e2c
90	Q28@cc49de72	Cleartext-Password	:=	9573c6
91	Q29@cc49de72	Cleartext-Password	:=	xxc3dy
92	Q30@cc49de72	Cleartext-Password	:=	3x99ya
93	Q31@cc49de72	Cleartext-Password	:=	3737b6
94	Q32@cc49de72	Cleartext-Password	:=	89efcb
95	Q33@cc49de72	Cleartext-Password	:=	c983d3
96	Q34@cc49de72	Cleartext-Password	:=	3y75ey
97	Q35@cc49de72	Cleartext-Password	:=	685fef
98	Q36@cc49de72	Cleartext-Password	:=	b63bd8
99	Q37@cc49de72	Cleartext-Password	:=	c3a5c2
100	Q38@cc49de72	Cleartext-Password	:=	6fy8yx
101	Q39@cc49de72	Cleartext-Password	:=	4e325f
102	Q40@cc49de72	Cleartext-Password	:=	b9d2ed
103	Q41@cc49de72	Cleartext-Password	:=	9542y4
104	Q42@cc49de72	Cleartext-Password	:=	7d36cb
105	Q43@cc49de72	Cleartext-Password	:=	5a64y2
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
64	2026-07-29 06:29:03.890552+00	R1@44a1539e		127.0.0.1	110402	DELETE FROM radcheck WHERE username = $1
65	2026-07-29 06:29:11.948237+00	R1@44a1539e		127.0.0.1	110402	DELETE FROM radcheck WHERE username = $1
66	2026-07-29 06:30:00.595341+00	R1@44a1539e		127.0.0.1	118060	DELETE FROM radcheck WHERE username = $1 OR username = $2
67	2026-07-29 08:59:00.784929+00	R4@44a1539e		127.0.0.1	132607	DELETE FROM radcheck WHERE username = $1 OR username = $2
68	2026-07-29 09:38:32.367997+00	R3@44a1539e		127.0.0.1	136839	DELETE FROM radcheck WHERE username = $1
69	2026-07-29 09:39:00.773104+00	R3@44a1539e		127.0.0.1	136926	DELETE FROM radcheck WHERE username = $1 OR username = $2
70	2026-07-29 09:54:22.553383+00	R3@44a1539e		127.0.0.1	138605	DELETE FROM radcheck WHERE username = $1
71	2026-07-29 09:54:56.551721+00	R3@44a1539e		127.0.0.1	138605	DELETE FROM radcheck WHERE username = $1
72	2026-07-29 09:55:56.549973+00	R3@44a1539e		127.0.0.1	138696	DELETE FROM radcheck WHERE username = $1
73	2026-07-29 09:56:00.674876+00	R3@44a1539e		127.0.0.1	138785	DELETE FROM radcheck WHERE username = $1 OR username = $2
74	2026-07-29 09:58:56.548591+00	3A:AD:23:80:40:76		127.0.0.1	138990	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
75	2026-07-29 09:59:02.217535+00	R4@44a1539e	psql	\N	139115	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
76	2026-07-29 10:09:58.577896+00	R3@44a1539e		127.0.0.1	140398	DELETE FROM radcheck WHERE username = $1
77	2026-07-29 10:10:00.987979+00	R3@44a1539e		127.0.0.1	140401	DELETE FROM radcheck WHERE username = $1 OR username = $2
78	2026-07-29 10:12:11.766902+00	R3@44a1539e		127.0.0.1	140691	DELETE FROM radcheck WHERE username = $1 OR username = $2
79	2026-07-29 10:12:56.55554+00	BC:2B:02:3A:7F:7C		127.0.0.1	140598	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
80	2026-07-29 10:14:15.690284+00	R3@44a1539e		127.0.0.1	140894	DELETE FROM radcheck WHERE username = $1
81	2026-07-29 10:15:00.135242+00	R3@44a1539e		127.0.0.1	140894	DELETE FROM radcheck WHERE username = $1 OR username = $2
82	2026-07-29 10:28:22.576623+00	R3@44a1539e		127.0.0.1	142594	DELETE FROM radcheck WHERE username = $1
83	2026-07-29 10:29:00.510709+00	R3@44a1539e		127.0.0.1	142684	DELETE FROM radcheck WHERE username = $1 OR username = $2
84	2026-07-29 10:31:56.568283+00	R3@44a1539e		127.0.0.1	142875	DELETE FROM radcheck WHERE username = $1
85	2026-07-29 10:33:27.071293+00	R3@44a1539e		127.0.0.1	143079	DELETE FROM radcheck WHERE username = $1
86	2026-07-29 10:34:00.671777+00	R3@44a1539e		127.0.0.1	143079	DELETE FROM radcheck WHERE username = $1 OR username = $2
87	2026-07-29 10:49:16.427826+00	R6@44a1539e		127.0.0.1	144851	DELETE FROM radcheck WHERE username = $1
88	2026-07-29 10:50:13.295514+00	R6@44a1539e		127.0.0.1	144947	DELETE FROM radcheck WHERE username = $1 OR username = $2
89	2026-07-29 11:33:51.130807+00	BC:2B:02:3A:7F:7C		127.0.0.1	149113	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
90	2026-07-29 11:34:01.908114+00	R3@44a1539e	psql	\N	149235	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
91	2026-07-29 11:49:51.134106+00	9E:A0:95:3A:BF:8D		127.0.0.1	150645	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
92	2026-07-29 11:50:02.498424+00	R6@44a1539e	psql	\N	150773	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
93	2026-07-29 13:46:38.498546+00	R6@44a1539e		127.0.0.1	162045	DELETE FROM radcheck WHERE username = $1
94	2026-07-29 13:48:13.757314+00	R6@44a1539e		127.0.0.1	162336	DELETE FROM radcheck WHERE username = $1 OR username = $2
95	2026-07-29 14:47:01.4162+00	R6@44a1539e	psql	\N	168246	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
96	2026-07-29 19:29:04.745928+00	R7@44a1539e		127.0.0.1	194665	DELETE FROM radcheck WHERE username = $1
97	2026-07-29 19:30:00.431458+00	R7@44a1539e		127.0.0.1	194665	DELETE FROM radcheck WHERE username = $1 OR username = $2
98	2026-07-29 19:31:00.447352+00	R8@44a1539e		127.0.0.1	194665	DELETE FROM radcheck WHERE username = $1 OR username = $2
99	2026-07-29 20:29:38.678305+00	A6:0B:69:D9:3A:6D		127.0.0.1	200467	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
100	2026-07-29 20:30:02.375368+00	R7@44a1539e	psql	\N	200599	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
101	2026-07-29 20:31:02.271099+00	R8@44a1539e	psql	\N	200694	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
102	2026-07-29 20:31:38.679205+00	CE:C4:E5:8C:D3:53		127.0.0.1	200659	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
103	2026-07-30 06:29:38.949048+00	66:87:6A:49:95:DA		127.0.0.1	258858	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
104	2026-07-30 06:30:02.7341+00	R1@44a1539e	psql	\N	258979	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
105	2026-07-30 08:12:55.267792+00	R6@44a1539e		127.0.0.1	268567	DELETE FROM radcheck WHERE username = $1
106	2026-07-30 08:13:09.75131+00	R6@44a1539e		127.0.0.1	268762	DELETE FROM radcheck WHERE username = $1 OR username = $2
107	2026-07-30 14:24:23.532558+00	R6@44a1539e		127.0.0.1	305141	DELETE FROM radcheck WHERE username = $1 OR username = $2
108	2026-07-30 14:28:12.638789+00	R1@44a1539e		127.0.0.1	305536	DELETE FROM radcheck WHERE username = $1
109	2026-07-30 14:28:12.650958+00	66:87:6A:49:95:DA		127.0.0.1	305536	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
110	2026-07-30 14:30:00.795711+00	R1@44a1539e		127.0.0.1	305723	DELETE FROM radcheck WHERE username = $1 OR username = $2
111	2026-07-30 14:30:11.584233+00	R6@44a1539e		127.0.0.1	305723	DELETE FROM radcheck WHERE username = $1 OR username = $2
112	2026-07-30 14:30:12.638504+00	R6@44a1539e		127.0.0.1	305729	DELETE FROM radcheck WHERE username = $1
113	2026-07-30 14:31:12.638382+00	R6@44a1539e		127.0.0.1	305819	DELETE FROM radcheck WHERE username = $1
114	2026-07-30 14:32:11.442564+00	R1@44a1539e		127.0.0.1	305911	DELETE FROM radcheck WHERE username = $1
115	2026-07-30 14:33:00.875953+00	R1@44a1539e		127.0.0.1	305910	DELETE FROM radcheck WHERE username = $1 OR username = $2
116	2026-07-30 15:30:02.525641+00	R6@44a1539e	psql	\N	312292	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
209	2026-08-01 14:44:03.515955+00	R9@4ed565d4		127.0.0.1	42731	DELETE FROM radcheck WHERE username = $1 OR username = $2
247	2026-08-02 06:47:01.007+00	R3@5a378a4e		127.0.0.1	160834	DELETE FROM radcheck WHERE username = $1 OR username = $2
117	2026-07-30 15:32:59.838808+00	66:87:6A:49:95:DA		127.0.0.1	312353	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
118	2026-07-30 15:33:01.696331+00	R1@44a1539e	psql	\N	312581	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
119	2026-07-30 17:21:10.916931+00	R6@44a1539e		127.0.0.1	323755	DELETE FROM radcheck WHERE username = $1 OR username = $2
120	2026-07-31 11:12:03.90075+00	R1@98d7ba07		127.0.0.1	21031	DELETE FROM radcheck WHERE username = $1 OR username = $2
121	2026-07-31 11:15:03.079935+00	R1@98d7ba07		127.0.0.1	21285	DELETE FROM radcheck WHERE username = $1
122	2026-07-31 11:15:11.098883+00	R1@98d7ba07		127.0.0.1	21285	DELETE FROM radcheck WHERE username = $1
123	2026-07-31 11:16:00.748546+00	R1@98d7ba07		127.0.0.1	21281	DELETE FROM radcheck WHERE username = $1 OR username = $2
124	2026-07-31 12:12:02.327272+00	K1@98d7ba07	psql	\N	27144	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
125	2026-07-31 12:15:19.224788+00	66:87:6A:49:95:DA		127.0.0.1	27536	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
126	2026-07-31 12:16:01.890375+00	R1@98d7ba07	psql	\N	27664	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
127	2026-07-31 12:57:00.608735+00	R1@98d7ba07		127.0.0.1	31994	DELETE FROM radcheck WHERE username = $1 OR username = $2
128	2026-07-31 13:57:02.113284+00	R1@98d7ba07	psql	\N	37451	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
129	2026-07-31 13:57:28.790809+00	66:87:6A:49:95:DA		127.0.0.1	37418	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
130	2026-07-31 17:09:48.025504+00	R3@98d7ba07		127.0.0.1	54388	DELETE FROM radcheck WHERE username = $1
131	2026-07-31 17:10:03.57332+00	R3@98d7ba07		127.0.0.1	54455	DELETE FROM radcheck WHERE username = $1 OR username = $2
132	2026-07-31 17:25:36.974024+00	66:87:6A:49:95:DA		127.0.0.1	56139	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
133	2026-07-31 17:27:36.871286+00	R3@98d7ba07		127.0.0.1	56246	DELETE FROM radcheck WHERE username = $1
134	2026-07-31 17:27:43.481251+00	R3@98d7ba07		127.0.0.1	56246	DELETE FROM radcheck WHERE username = $1
135	2026-07-31 17:28:14.129293+00	R3@98d7ba07		127.0.0.1	56319	DELETE FROM radcheck WHERE username = $1 OR username = $2
136	2026-07-31 17:29:45.520969+00	R3@98d7ba07		127.0.0.1	56460	DELETE FROM radcheck WHERE username = $1 OR username = $2
137	2026-07-31 17:33:05.384754+00	R3@98d7ba07		127.0.0.1	56726	DELETE FROM radcheck WHERE username = $1 OR username = $2
138	2026-07-31 17:34:50.991859+00	R1@98d7ba07		127.0.0.1	56815	DELETE FROM radcheck WHERE username = $1
139	2026-07-31 17:35:00.199849+00	R1@98d7ba07		127.0.0.1	56814	DELETE FROM radcheck WHERE username = $1 OR username = $2
140	2026-07-31 18:16:40.496751+00	R1@98d7ba07		127.0.0.1	61408	DELETE FROM radcheck WHERE username = $1 OR username = $2
141	2026-07-31 18:17:30.00774+00	66:87:6A:49:95:DA		127.0.0.1	61555	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
142	2026-07-31 18:42:00.15369+00	B1@15c14766		127.0.0.1	63749	DELETE FROM radcheck WHERE username = $1 OR username = $2
143	2026-07-31 19:08:42.052554+00	B1@15c14766		127.0.0.1	66537	DELETE FROM radcheck WHERE username = $1
144	2026-07-31 19:09:00.815479+00	B1@15c14766		127.0.0.1	66537	DELETE FROM radcheck WHERE username = $1 OR username = $2
145	2026-07-31 20:09:01.727392+00	B1@15c14766	psql	\N	72723	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
146	2026-07-31 20:09:30.142196+00	66:87:6A:49:95:DA		127.0.0.1	72690	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
147	2026-07-31 23:00:02.707703+00	B17@15c14766	psql	\N	95159	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
148	2026-07-31 23:07:02.224155+00	B23@15c14766	psql	\N	96793	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
149	2026-07-31 23:09:01.524461+00	B21@15c14766	psql	\N	97250	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
150	2026-08-01 00:44:02.02337+00	B18@15c14766	psql	\N	119360	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
175	2026-08-01 07:19:35.535216+00	9E:A0:95:3A:BF:8D		127.0.0.1	212842	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
151	2026-08-01 02:10:01.420901+00	B28@15c14766	psql	\N	139643	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
152	2026-08-01 02:14:02.273252+00	B24@15c14766	psql	\N	140565	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
153	2026-08-01 04:08:01.59639+00	B9@15c14766	psql	\N	167150	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
154	2026-08-01 04:22:01.662391+00	B25@15c14766	psql	\N	170525	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
155	2026-08-01 04:24:00.637771+00	B30@15c14766		127.0.0.1	170731	DELETE FROM radcheck WHERE username = $1 OR username = $2
156	2026-08-01 04:39:01.455261+00	B11@15c14766	psql	\N	174507	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
157	2026-08-01 04:44:02.052187+00	B5@15c14766	psql	\N	175668	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
158	2026-08-01 04:57:01.791558+00	B10@15c14766	psql	\N	178699	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
159	2026-08-01 04:57:01.791558+00	B14@15c14766	psql	\N	178699	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
160	2026-08-01 05:23:02.227166+00	B2@15c14766	psql	\N	184811	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
161	2026-08-01 05:23:02.227166+00	B29@15c14766	psql	\N	184811	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
162	2026-08-01 05:23:02.227166+00	B30@15c14766	psql	\N	184811	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
163	2026-08-01 05:23:03.282249+00	3A:AD:23:80:40:76		127.0.0.1	184774	\n        WITH expired AS (\n          SELECT used_by_mac AS m FROM hotspot_vouchers\n           WHERE status='expired' AND used_by_mac IS NOT NULL AND used_by_mac <> ''\n             AND expires_at IS NOT NULL AND expires_at < NOW()\n        ),\n        forms AS (\n          SELECT lower(m) AS mform FROM expired\n          UNION SELECT upper(m) FROM expired\n        )\n        DELETE FROM radcheck WHERE username IN (SELECT mform FROM forms) RETURNING username\n      
164	2026-08-01 05:34:02.281235+00	B19@15c14766	psql	\N	187363	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
165	2026-08-01 05:53:01.299638+00	B8@15c14766	psql	\N	191817	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
166	2026-08-01 05:58:01.684503+00	B26@15c14766	psql	\N	192981	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
167	2026-08-01 06:06:00.253608+00	B1@15c14766		127.0.0.1	194802	DELETE FROM radcheck WHERE username = $1 OR username = $2
168	2026-08-01 06:20:00.691518+00	B31@15c14766		127.0.0.1	197879	DELETE FROM radcheck WHERE username = $1 OR username = $2
169	2026-08-01 06:37:01.328248+00	B6@15c14766	psql	\N	202121	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
170	2026-08-01 06:38:37.78318+00	B1@15c14766		127.0.0.1	202326	DELETE FROM radcheck WHERE username = $1 OR username = $2
171	2026-08-01 06:39:35.525049+00	66:87:6A:49:95:DA		127.0.0.1	202546	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
172	2026-08-01 06:43:10.838777+00	B32@15c14766		127.0.0.1	203490	DELETE FROM radcheck WHERE username = $1 OR username = $2
173	2026-08-01 06:52:01.775238+00	B20@15c14766	psql	\N	205622	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
174	2026-08-01 07:11:01.320029+00	B7@15c14766	psql	\N	210943	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
176	2026-08-01 07:20:02.605084+00	B31@15c14766	psql	\N	213125	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
177	2026-08-01 07:43:01.626578+00	B32@15c14766	psql	\N	218577	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
178	2026-08-01 09:28:02.210503+00	B12@15c14766	psql	\N	243383	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
179	2026-08-01 11:42:00.108548+00	R1@4ed565d4		127.0.0.1	2034	DELETE FROM radcheck WHERE username = $1 OR username = $2
180	2026-08-01 11:51:04.166063+00	R2@4ed565d4		127.0.0.1	3200	DELETE FROM radcheck WHERE username = $1
181	2026-08-01 11:51:12.172333+00	R2@4ed565d4		127.0.0.1	3200	DELETE FROM radcheck WHERE username = $1
182	2026-08-01 11:52:03.741684+00	R2@4ed565d4		127.0.0.1	3287	DELETE FROM radcheck WHERE username = $1 OR username = $2
183	2026-08-01 12:03:24.460756+00	BC:2B:02:3A:7F:7C		127.0.0.1	4425	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
184	2026-08-01 12:41:24.476433+00	66:87:6A:49:95:DA		127.0.0.1	12980	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
185	2026-08-01 12:42:02.213858+00	R1@4ed565d4	psql	\N	13249	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
186	2026-08-01 12:47:24.477823+00	9E:A0:95:3A:BF:8D		127.0.0.1	14420	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
187	2026-08-01 12:52:01.757712+00	R2@4ed565d4	psql	\N	15621	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
188	2026-08-01 13:05:03.356397+00	R2@4ed565d4		127.0.0.1	18646	DELETE FROM radcheck WHERE username = $1 OR username = $2
189	2026-08-01 13:54:00.281701+00	R1@4ed565d4		127.0.0.1	30628	DELETE FROM radcheck WHERE username = $1 OR username = $2
190	2026-08-01 14:05:01.434335+00	R2@4ed565d4	psql	\N	33337	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
191	2026-08-01 14:06:27.729601+00	R1@4ed565d4		127.0.0.1	33531	DELETE FROM radcheck WHERE username = $1 OR username = $2
192	2026-08-01 14:06:31.472395+00	66:87:6A:49:95:DA		127.0.0.1	33532	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
193	2026-08-01 14:09:00.79696+00	R1@4ed565d4		127.0.0.1	33996	DELETE FROM radcheck WHERE username = $1 OR username = $2
194	2026-08-01 14:19:46.685541+00	R1@4ed565d4		127.0.0.1	36854	DELETE FROM radcheck WHERE username = $1 OR username = $2
195	2026-08-01 14:21:00.342408+00	R1@4ed565d4		127.0.0.1	37113	DELETE FROM radcheck WHERE username = $1 OR username = $2
196	2026-08-01 14:28:02.189997+00	R9@4ed565d4	psql	\N	38906	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
197	2026-08-01 14:29:39.398477+00	R1@4ed565d4		127.0.0.1	39329	DELETE FROM radcheck WHERE username = $1 OR username = $2
198	2026-08-01 14:29:48.892084+00	66:87:6A:49:95:DA		127.0.0.1	38879	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
199	2026-08-01 14:29:48.892084+00	66:87:6A:49:95:DA		127.0.0.1	38879	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
200	2026-08-01 14:30:56.47449+00	R9@4ed565d4		127.0.0.1	39344	DELETE FROM radcheck WHERE username = $1 OR username = $2
201	2026-08-01 14:31:24.251214+00	R9@4ed565d4		127.0.0.1	39595	DELETE FROM radcheck WHERE username = $1 OR username = $2
202	2026-08-01 14:31:48.890734+00	66:87:6A:49:95:DA		127.0.0.1	39585	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
203	2026-08-01 14:33:10.201038+00	R2@4ed565d4		127.0.0.1	40060	DELETE FROM radcheck WHERE username = $1 OR username = $2
204	2026-08-01 14:35:00.160016+00	R10@4ed565d4		127.0.0.1	40504	DELETE FROM radcheck WHERE username = $1 OR username = $2
205	2026-08-01 14:38:42.13318+00	66:87:6A:49:95:DA		127.0.0.1	41505	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
206	2026-08-01 14:39:01.846317+00	R2@4ed565d4	psql	\N	41555	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
207	2026-08-01 14:39:01.846317+00	R10@4ed565d4	psql	\N	41555	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
208	2026-08-01 14:41:00.153733+00	R9@4ed565d4		127.0.0.1	42005	DELETE FROM radcheck WHERE username = $1 OR username = $2
210	2026-08-01 14:44:59.186141+00	66:87:6A:49:95:DA		127.0.0.1	42953	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
211	2026-08-01 14:46:00.325046+00	R11@4ed565d4		127.0.0.1	42966	DELETE FROM radcheck WHERE username = $1 OR username = $2
212	2026-08-01 15:00:02.663374+00	R11@4ed565d4	psql	\N	55509	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
213	2026-08-01 15:00:02.663374+00	R10@4ed565d4	psql	\N	55509	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
214	2026-08-01 15:00:45.346654+00	66:87:6A:49:95:DA		127.0.0.1	55462	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
215	2026-08-01 15:03:00.625909+00	R11@4ed565d4		127.0.0.1	56184	DELETE FROM radcheck WHERE username = $1 OR username = $2
216	2026-08-01 15:07:02.2613+00	R6@4ed565d4	psql	\N	57177	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
217	2026-08-01 15:15:14.742399+00	R11@4ed565d4		127.0.0.1	59185	DELETE FROM radcheck WHERE username = $1 OR username = $2
218	2026-08-01 15:15:45.353164+00	66:87:6A:49:95:DA		127.0.0.1	59184	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
219	2026-08-01 15:16:53.932427+00	R12@4ed565d4		127.0.0.1	59446	DELETE FROM radcheck WHERE username = $1 OR username = $2
220	2026-08-01 15:17:34.454947+00	R12@4ed565d4		127.0.0.1	59675	DELETE FROM radcheck WHERE username = $1 OR username = $2
221	2026-08-01 15:17:45.353857+00	66:87:6A:49:95:DA		127.0.0.1	59675	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
222	2026-08-01 15:19:00.160765+00	R13@4ed565d4		127.0.0.1	59916	DELETE FROM radcheck WHERE username = $1 OR username = $2
223	2026-08-01 15:22:08.974871+00	R13@4ed565d4		127.0.0.1	60866	DELETE FROM radcheck WHERE username = $1 OR username = $2
224	2026-08-01 15:23:01.852221+00	66:87:6A:49:95:DA		127.0.0.1	60858	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
225	2026-08-01 15:24:00.606332+00	R14@4ed565d4		127.0.0.1	61329	DELETE FROM radcheck WHERE username = $1 OR username = $2
226	2026-08-01 15:24:18.566611+00	R14@4ed565d4		127.0.0.1	61334	DELETE FROM radcheck WHERE username = $1 OR username = $2
227	2026-08-01 15:25:01.746769+00	66:87:6A:49:95:DA		127.0.0.1	61554	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
228	2026-08-01 15:25:09.680755+00	R15@4ed565d4		127.0.0.1	61560	DELETE FROM radcheck WHERE username = $1
229	2026-08-01 15:26:00.840456+00	R15@4ed565d4		127.0.0.1	61799	DELETE FROM radcheck WHERE username = $1 OR username = $2
230	2026-08-01 15:35:21.933556+00	R15@4ed565d4		127.0.0.1	63949	DELETE FROM radcheck WHERE username = $1 OR username = $2
231	2026-08-01 15:35:38.262121+00	66:87:6A:49:95:DA		127.0.0.1	63952	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
232	2026-08-01 15:44:00.58338+00	R16@4ed565d4		127.0.0.1	66081	DELETE FROM radcheck WHERE username = $1 OR username = $2
233	2026-08-01 15:45:17.697243+00	R16@4ed565d4		127.0.0.1	66310	DELETE FROM radcheck WHERE username = $1 OR username = $2
234	2026-08-01 15:45:38.259492+00	66:87:6A:49:95:DA		127.0.0.1	66293	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
235	2026-08-01 15:46:25.86618+00	R17@4ed565d4		127.0.0.1	66554	DELETE FROM radcheck WHERE username = $1
236	2026-08-01 15:47:00.686401+00	R17@4ed565d4		127.0.0.1	66767	DELETE FROM radcheck WHERE username = $1 OR username = $2
237	2026-08-01 15:55:43.633723+00	66:87:6A:49:95:DA		127.0.0.1	68278	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
238	2026-08-01 15:56:02.373412+00	R17@4ed565d4	psql	\N	69034	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
239	2026-08-01 15:58:00.656521+00	R18@4ed565d4		127.0.0.1	69516	DELETE FROM radcheck WHERE username = $1 OR username = $2
240	2026-08-01 15:58:08.529744+00	R18@4ed565d4		127.0.0.1	69522	DELETE FROM radcheck WHERE username = $1
241	2026-08-01 16:20:00.398584+00	R1@5a378a4e		127.0.0.1	72376	DELETE FROM radcheck WHERE username = $1 OR username = $2
242	2026-08-01 16:20:29.852399+00	R1@5a378a4e		127.0.0.1	72401	DELETE FROM radcheck WHERE username = $1 OR username = $2
243	2026-08-01 16:21:24.497572+00	66:87:6A:49:95:DA		127.0.0.1	72511	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
244	2026-08-01 16:23:00.441363+00	R2@5a378a4e		127.0.0.1	72609	DELETE FROM radcheck WHERE username = $1 OR username = $2
245	2026-08-01 17:23:01.6043+00	R2@5a378a4e	psql	\N	78776	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
246	2026-08-01 17:23:24.521185+00	66:87:6A:49:95:DA		127.0.0.1	78749	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
248	2026-08-02 06:50:03.945654+00	R3@5a378a4e		127.0.0.1	161144	DELETE FROM radcheck WHERE username = $1 OR username = $2
249	2026-08-02 06:50:13.884461+00	66:87:6A:49:95:DA		127.0.0.1	161145	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
250	2026-08-02 06:52:00.175527+00	R5@5a378a4e		127.0.0.1	161361	DELETE FROM radcheck WHERE username = $1 OR username = $2
251	2026-08-02 07:01:06.699873+00	R4@5a378a4e		127.0.0.1	162468	DELETE FROM radcheck WHERE username = $1 OR username = $2
252	2026-08-02 07:01:12.901734+00	R5@5a378a4e		127.0.0.1	162467	DELETE FROM radcheck WHERE username = $1 OR username = $2
253	2026-08-02 07:02:08.002855+00	66:87:6A:49:95:DA		127.0.0.1	162558	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
254	2026-08-02 07:03:00.197055+00	R6@5a378a4e		127.0.0.1	162662	DELETE FROM radcheck WHERE username = $1 OR username = $2
255	2026-08-02 07:17:13.324344+00	R6@5a378a4e		127.0.0.1	164496	DELETE FROM radcheck WHERE username = $1 OR username = $2
256	2026-08-02 07:17:48.805788+00	66:87:6A:49:95:DA		127.0.0.1	164496	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
257	2026-08-02 08:07:36.119725+00	R1@5a378a4e		127.0.0.1	170032	DELETE FROM radcheck WHERE username = $1
258	2026-08-02 08:17:45.303142+00	R1@5a378a4e		127.0.0.1	171013	DELETE FROM radcheck WHERE username = $1 OR username = $2
259	2026-08-02 08:17:45.344861+00	R1@5a378a4e		127.0.0.1	171013	DELETE FROM radcheck WHERE username = $1
260	2026-08-02 08:18:49.003635+00	R1@5a378a4e		127.0.0.1	171108	DELETE FROM radcheck WHERE username = $1 OR username = $2
261	2026-08-02 08:19:47.379225+00	66:87:6A:49:95:DA		127.0.0.1	171108	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
262	2026-08-02 08:20:47.386414+00	R1@5a378a4e		127.0.0.1	171296	DELETE FROM radcheck WHERE username = $1
263	2026-08-02 08:21:47.386215+00	R1@5a378a4e		127.0.0.1	171402	DELETE FROM radcheck WHERE username = $1
264	2026-08-02 08:29:03.268994+00	K1@5a378a4e		127.0.0.1	172182	DELETE FROM radcheck WHERE username = $1 OR username = $2
265	2026-08-02 08:39:46.329217+00	K1@5a378a4e		127.0.0.1	173344	DELETE FROM radcheck WHERE username = $1 OR username = $2
266	2026-08-02 08:39:52.185445+00	R1@5a378a4e		127.0.0.1	173344	DELETE FROM radcheck WHERE username = $1 OR username = $2
267	2026-08-02 08:40:02.912742+00	66:87:6A:49:95:DA		127.0.0.1	173367	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
268	2026-08-02 13:27:00.601666+00	R1@5a378a4e		127.0.0.1	200981	DELETE FROM radcheck WHERE username = $1 OR username = $2
269	2026-08-02 13:27:34.81963+00	R1@5a378a4e		127.0.0.1	201146	DELETE FROM radcheck WHERE username = $1
270	2026-08-02 13:28:00.637021+00	R1@5a378a4e		127.0.0.1	201069	DELETE FROM radcheck WHERE username = $1 OR username = $2
271	2026-08-02 13:28:07.410127+00	R1@5a378a4e		127.0.0.1	201153	DELETE FROM radcheck WHERE username = $1
272	2026-08-02 13:29:07.40915+00	R1@5a378a4e		127.0.0.1	201235	DELETE FROM radcheck WHERE username = $1
273	2026-08-02 13:36:00.151192+00	R7@5a378a4e		127.0.0.1	201964	DELETE FROM radcheck WHERE username = $1 OR username = $2
274	2026-08-02 13:46:22.461786+00	R1@5a378a4e		127.0.0.1	203095	DELETE FROM radcheck WHERE username = $1
275	2026-08-02 13:47:00.643922+00	R1@5a378a4e		127.0.0.1	203099	DELETE FROM radcheck WHERE username = $1 OR username = $2
276	2026-08-02 13:58:09.667815+00	R1@5a378a4e		127.0.0.1	204319	DELETE FROM radcheck WHERE username = $1
277	2026-08-02 13:58:39.509279+00	R1@5a378a4e		127.0.0.1	204319	DELETE FROM radcheck WHERE username = $1
278	2026-08-02 13:59:39.509751+00	R1@5a378a4e		127.0.0.1	204401	DELETE FROM radcheck WHERE username = $1
279	2026-08-02 14:00:00.894061+00	R1@5a378a4e		127.0.0.1	204401	DELETE FROM radcheck WHERE username = $1 OR username = $2
280	2026-08-02 14:09:25.245739+00	R1@5a378a4e		127.0.0.1	205387	DELETE FROM radcheck WHERE username = $1
281	2026-08-02 14:10:00.601135+00	R1@5a378a4e		127.0.0.1	205383	DELETE FROM radcheck WHERE username = $1 OR username = $2
282	2026-08-02 14:16:56.760581+00	R1@5a378a4e		127.0.0.1	206078	DELETE FROM radcheck WHERE username = $1
283	2026-08-02 14:17:00.85177+00	R1@5a378a4e		127.0.0.1	206167	DELETE FROM radcheck WHERE username = $1 OR username = $2
284	2026-08-02 14:17:02.562953+00	R1@5a378a4e		127.0.0.1	206168	DELETE FROM radcheck WHERE username = $1
285	2026-08-02 14:18:02.620794+00	R1@5a378a4e		127.0.0.1	206261	DELETE FROM radcheck WHERE username = $1
286	2026-08-02 14:26:46.311646+00	R1@5a378a4e		127.0.0.1	207088	DELETE FROM radcheck WHERE username = $1
287	2026-08-02 14:27:00.138282+00	R1@5a378a4e		127.0.0.1	207090	DELETE FROM radcheck WHERE username = $1 OR username = $2
288	2026-08-02 14:31:24.964095+00	R1@5a378a4e		127.0.0.1	207624	DELETE FROM radcheck WHERE username = $1
289	2026-08-02 14:32:11.490956+00	R1@5a378a4e		127.0.0.1	207707	DELETE FROM radcheck WHERE username = $1
290	2026-08-02 14:33:00.184231+00	R1@5a378a4e		127.0.0.1	207713	DELETE FROM radcheck WHERE username = $1 OR username = $2
291	2026-08-02 14:36:02.299249+00	R7@5a378a4e	psql	\N	208143	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
292	2026-08-02 14:36:21.802523+00	A6:0B:69:D9:3A:6D		127.0.0.1	208224	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
293	2026-08-02 14:37:10.30665+00	R1@5a378a4e		127.0.0.1	208234	DELETE FROM radcheck WHERE username = $1
294	2026-08-02 14:37:21.765119+00	R1@5a378a4e		127.0.0.1	208224	DELETE FROM radcheck WHERE username = $1
295	2026-08-02 14:39:03.880858+00	K1@5a378a4e		127.0.0.1	208438	DELETE FROM radcheck WHERE username = $1 OR username = $2
296	2026-08-02 14:42:47.193352+00	K1@5a378a4e		127.0.0.1	208824	DELETE FROM radcheck WHERE username = $1 OR username = $2
297	2026-08-02 14:44:24.804302+00	R1@5a378a4e		127.0.0.1	208921	DELETE FROM radcheck WHERE username = $1
298	2026-08-02 14:45:03.06844+00	R1@5a378a4e		127.0.0.1	209021	DELETE FROM radcheck WHERE username = $1 OR username = $2
299	2026-08-02 14:54:03.87335+00	R1@5a378a4e		127.0.0.1	209872	DELETE FROM radcheck WHERE username = $1 OR username = $2
340	2026-08-03 12:45:46.916424+00	Q2@cc49de72		127.0.0.1	351099	DELETE FROM radcheck WHERE username = $1 OR username = $2
300	2026-08-02 14:54:21.776882+00	66:87:6A:49:95:DA		127.0.0.1	209871	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
301	2026-08-02 14:57:03.846745+00	R1@5a378a4e		127.0.0.1	210171	DELETE FROM radcheck WHERE username = $1 OR username = $2
302	2026-08-02 15:07:36.782516+00	K1@5a378a4e		127.0.0.1	211736	DELETE FROM radcheck WHERE username = $1 OR username = $2
303	2026-08-02 15:08:55.760731+00	R1@5a378a4e		127.0.0.1	211819	DELETE FROM radcheck WHERE username = $1
304	2026-08-02 15:09:03.745872+00	R1@5a378a4e		127.0.0.1	211899	DELETE FROM radcheck WHERE username = $1 OR username = $2
305	2026-08-02 15:57:02.115702+00	K1@5a378a4e	psql	\N	216473	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
306	2026-08-02 16:09:01.714664+00	R1@5a378a4e	psql	\N	217603	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
307	2026-08-02 16:09:47.647253+00	66:87:6A:49:95:DA		127.0.0.1	217571	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
308	2026-08-02 20:15:03.608264+00	R8@5a378a4e		127.0.0.1	244537	DELETE FROM radcheck WHERE username = $1 OR username = $2
309	2026-08-02 20:30:38.010094+00	R8@5a378a4e		127.0.0.1	246874	DELETE FROM radcheck WHERE username = $1
310	2026-08-02 20:31:03.894084+00	R8@5a378a4e		127.0.0.1	246873	DELETE FROM radcheck WHERE username = $1 OR username = $2
311	2026-08-02 20:34:05.89349+00	R9@5a378a4e		127.0.0.1	247165	DELETE FROM radcheck WHERE username = $1
312	2026-08-02 20:35:01.028504+00	R9@5a378a4e		127.0.0.1	247165	DELETE FROM radcheck WHERE username = $1 OR username = $2
313	2026-08-02 20:36:58.977052+00	R9@5a378a4e		127.0.0.1	247385	DELETE FROM radcheck WHERE username = $1 OR username = $2
314	2026-08-02 20:37:34.788191+00	72:5A:97:02:DC:D0		127.0.0.1	247385	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
315	2026-08-02 20:38:29.199471+00	R8@5a378a4e		127.0.0.1	247584	DELETE FROM radcheck WHERE username = $1 OR username = $2
316	2026-08-02 20:44:03.245123+00	R8@5a378a4e		127.0.0.1	248185	DELETE FROM radcheck WHERE username = $1 OR username = $2
317	2026-08-02 20:48:00.505232+00	R9@5a378a4e		127.0.0.1	248503	DELETE FROM radcheck WHERE username = $1 OR username = $2
318	2026-08-02 21:44:02.155706+00	R8@5a378a4e	psql	\N	254306	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
319	2026-08-02 21:47:34.832382+00	72:5A:97:02:DC:D0		127.0.0.1	254587	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
320	2026-08-02 21:48:02.229262+00	R9@5a378a4e	psql	\N	254725	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
321	2026-08-03 08:16:00.602676+00	R1@5a378a4e		127.0.0.1	318555	DELETE FROM radcheck WHERE username = $1 OR username = $2
322	2026-08-03 08:22:03.876127+00	R8@5a378a4e		127.0.0.1	319286	DELETE FROM radcheck WHERE username = $1 OR username = $2
323	2026-08-03 08:25:25.970189+00	R1@5a378a4e		127.0.0.1	319585	DELETE FROM radcheck WHERE username = $1 OR username = $2
324	2026-08-03 08:25:33.441002+00	R8@5a378a4e		127.0.0.1	319587	DELETE FROM radcheck WHERE username = $1 OR username = $2
325	2026-08-03 08:25:35.098267+00	66:87:6A:49:95:DA		127.0.0.1	319580	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
326	2026-08-03 09:25:41.673192+00	R1@5a378a4e		127.0.0.1	326960	DELETE FROM radcheck WHERE username = $1 OR username = $2
327	2026-08-03 09:26:32.306394+00	66:87:6A:49:95:DA		127.0.0.1	327079	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
328	2026-08-03 09:27:32.301043+00	R1@5a378a4e		127.0.0.1	327189	DELETE FROM radcheck WHERE username = $1
329	2026-08-03 09:53:13.272805+00	R1@5a378a4e		127.0.0.1	330060	DELETE FROM radcheck WHERE username = $1 OR username = $2
330	2026-08-03 09:53:19.790231+00	66:87:6A:49:95:DA		127.0.0.1	330053	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
331	2026-08-03 10:56:38.710065+00	66:87:6A:49:95:DA		127.0.0.1	338509	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
332	2026-08-03 10:57:02.139697+00	R1@5a378a4e	psql	\N	338681	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
333	2026-08-03 12:26:24.516778+00	Q1@cc49de72		127.0.0.1	349084	DELETE FROM radcheck WHERE username = $1
334	2026-08-03 12:26:25.716776+00	Q1@cc49de72		127.0.0.1	349084	DELETE FROM radcheck WHERE username = $1 OR username = $2
335	2026-08-03 12:32:24.37039+00	Q2@cc49de72		127.0.0.1	349687	DELETE FROM radcheck WHERE username = $1
336	2026-08-03 12:32:24.403195+00	Q2@cc49de72		127.0.0.1	349687	DELETE FROM radcheck WHERE username = $1 OR username = $2
337	2026-08-03 12:33:33.567068+00	Q2@cc49de72		127.0.0.1	349781	DELETE FROM radcheck WHERE username = $1 OR username = $2
338	2026-08-03 12:33:42.169821+00	AE:C1:5C:88:4A:7F		127.0.0.1	349781	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
339	2026-08-03 12:44:53.298659+00	Q1@cc49de72		127.0.0.1	350909	DELETE FROM radcheck WHERE username = $1 OR username = $2
341	2026-08-03 12:46:42.177935+00	AE:C1:5C:88:4A:7F		127.0.0.1	351115	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
342	2026-08-03 12:53:56.460481+00	Q1@cc49de72		127.0.0.1	351814	DELETE FROM radcheck WHERE username = $1 OR username = $2
343	2026-08-03 13:31:42.185546+00	AE:C1:5C:88:4A:7F		127.0.0.1	355643	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
344	2026-08-03 13:55:38.670859+00	Q1@cc49de72		127.0.0.1	358886	DELETE FROM radcheck WHERE username = $1 OR username = $2
345	2026-08-03 13:55:52.846923+00	66:87:6A:49:95:DA		127.0.0.1	358884	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
346	2026-08-03 13:56:02.280044+00	Q2@cc49de72	psql	\N	358931	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
347	2026-08-03 13:57:52.30584+00	Q1@cc49de72		127.0.0.1	358999	DELETE FROM radcheck WHERE username = $1
348	2026-08-03 13:57:54.767323+00	Q1@cc49de72		127.0.0.1	359000	DELETE FROM radcheck WHERE username = $1 OR username = $2
349	2026-08-03 13:59:52.84788+00	66:87:6A:49:95:DA		127.0.0.1	359204	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
350	2026-08-03 14:30:03.024256+00	Q37@cc49de72		127.0.0.1	362872	DELETE FROM radcheck WHERE username = $1
351	2026-08-03 14:30:40.778775+00	Q3@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
352	2026-08-03 14:30:40.790217+00	Q4@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
353	2026-08-03 14:30:40.799594+00	Q5@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
354	2026-08-03 14:30:40.81161+00	Q6@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
355	2026-08-03 14:30:40.822881+00	Q7@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
356	2026-08-03 14:30:40.832806+00	Q8@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
357	2026-08-03 14:30:40.843031+00	Q9@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
358	2026-08-03 14:30:40.854383+00	Q10@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
359	2026-08-03 14:30:40.86566+00	Q11@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
360	2026-08-03 14:30:40.875398+00	Q12@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
361	2026-08-03 14:30:40.887473+00	Q13@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
362	2026-08-03 14:30:40.899522+00	Q14@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
363	2026-08-03 14:30:40.91117+00	Q15@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
364	2026-08-03 14:30:40.922086+00	Q16@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
365	2026-08-03 14:30:40.933002+00	Q17@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
366	2026-08-03 14:30:40.944275+00	Q18@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
367	2026-08-03 14:30:40.956099+00	Q19@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
368	2026-08-03 14:30:40.965803+00	Q20@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
369	2026-08-03 14:30:40.97585+00	Q21@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
370	2026-08-03 14:30:40.988051+00	Q22@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
371	2026-08-03 14:30:41.00124+00	Q23@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
372	2026-08-03 14:30:41.013862+00	Q24@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
373	2026-08-03 14:30:41.023456+00	Q25@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
374	2026-08-03 14:30:41.036233+00	Q26@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
375	2026-08-03 14:30:41.046535+00	Q27@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
376	2026-08-03 14:30:41.056605+00	Q28@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
377	2026-08-03 14:30:41.065888+00	Q29@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
378	2026-08-03 14:30:41.079572+00	Q30@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
379	2026-08-03 14:30:41.088654+00	Q31@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
380	2026-08-03 14:30:41.09936+00	Q32@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
381	2026-08-03 14:30:41.109951+00	Q33@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
382	2026-08-03 14:30:41.119167+00	Q34@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
383	2026-08-03 14:30:41.129533+00	Q35@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
384	2026-08-03 14:30:41.139038+00	Q36@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
385	2026-08-03 14:30:41.148294+00	Q37@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
386	2026-08-03 14:30:41.158362+00	Q38@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
387	2026-08-03 14:30:41.168224+00	Q39@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
388	2026-08-03 14:30:41.178238+00	Q40@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
389	2026-08-03 14:30:41.188143+00	Q41@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
390	2026-08-03 14:30:41.201524+00	Q42@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
391	2026-08-03 14:30:41.210875+00	Q43@cc49de72		127.0.0.1	363392	DELETE FROM radcheck WHERE username = $1
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
1	8C:44:BB:15:2C:70	RLMACAUTH	Access-Reject	2026-08-03 12:12:59.583686+00	\N
2	04:F4:1C:8D:29:BE	RLMACAUTH	Access-Reject	2026-08-03 12:13:10.053128+00	\N
3	06:FA:9B:93:3B:13	RLMACAUTH	Access-Reject	2026-08-03 12:13:10.244698+00	\N
4	04:F4:1C:8D:29:BE	RLMACAUTH	Access-Reject	2026-08-03 12:13:11.813121+00	\N
5	benard		Access-Accept	2026-08-03 12:14:18.002989+00	\N
6	benard		Access-Accept	2026-08-03 12:16:09.097093+00	\N
7	benard		Access-Accept	2026-08-03 12:16:51.815822+00	\N
8	benard		Access-Accept	2026-08-03 12:17:29.605872+00	\N
9	CC:2D:21:F5:12:A0	RLMACAUTH	Access-Reject	2026-08-03 12:22:17.187703+00	\N
10	AE:C1:5C:88:4A:7F	RLMACAUTH	Access-Reject	2026-08-03 12:22:18.060821+00	\N
11	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-08-03 12:22:56.26876+00	\N
12	CC:2D:21:F5:12:A0	RLMACAUTH	Access-Reject	2026-08-03 12:31:44.757387+00	\N
13	Q2@cc49de72	fe8ba5	Access-Accept	2026-08-03 12:32:28.54106+00	\N
14	AE:C1:5C:88:4A:7F	RLMACAUTH	Access-Reject	2026-08-03 12:34:17.261128+00	\N
15	Q2@cc49de72	fe8ba5	Access-Accept	2026-08-03 12:34:29.245636+00	\N
16	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-08-03 12:45:44.071168+00	\N
17	CC:2D:21:F5:12:A0	RLMACAUTH	Access-Reject	2026-08-03 12:46:46.523267+00	\N
18	Q2@cc49de72	fe8ba5	Access-Reject	2026-08-03 12:46:48.808052+00	\N
19	Q1@cc49de72	b9eye8	Access-Accept	2026-08-03 12:47:40.101676+00	\N
20	Q1@cc49de72	b9eye8	Access-Accept	2026-08-03 12:52:48.934316+00	\N
21	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-08-03 12:54:43.951575+00	\N
22	Q2@cc49de72	fe8ba5	Access-Accept	2026-08-03 12:55:23.206462+00	\N
23	CC:2D:21:F5:12:A0	RLMACAUTH	Access-Reject	2026-08-03 13:25:17.998367+00	\N
24	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-03 13:25:18.694714+00	\N
25	AE:C1:5C:88:4A:7F	RLMACAUTH	Access-Accept	2026-08-03 13:25:48.79902+00	\N
26	Q2@cc49de72	fe8ba5	Access-Accept	2026-08-03 13:31:13.096473+00	\N
27	CC:2D:21:F5:12:A0	RLMACAUTH	Access-Reject	2026-08-03 13:50:16.630542+00	\N
28	AE:C1:5C:88:4A:7F	RLMACAUTH	Access-Reject	2026-08-03 13:50:16.91511+00	\N
29	Q1@cc49de72	b9eye8	Access-Accept	2026-08-03 13:50:47.596229+00	\N
30	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-08-03 13:56:09.064373+00	\N
31	CC:2D:21:F5:12:A0	RLMACAUTH	Access-Reject	2026-08-03 13:56:44.207932+00	\N
32	Q1@cc49de72	b9eye8	Access-Reject	2026-08-03 13:56:49.568288+00	\N
33	Q2@cc49de72	fe8ba5	Access-Accept	2026-08-03 13:59:15.644238+00	\N
34	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-03 14:04:44.32052+00	\N
35	Q2@cc49de72	fe8ba5	Access-Accept	2026-08-03 14:05:34.083351+00	\N
36	benard		Access-Accept	2026-08-03 14:14:34.388244+00	\N
37	benard		Access-Accept	2026-08-03 14:15:02.039512+00	\N
38	benard		Access-Accept	2026-08-03 14:19:16.855749+00	\N
39	benard		Access-Accept	2026-08-03 14:22:59.484341+00	\N
40	benard		Access-Accept	2026-08-03 14:28:08.244751+00	\N
41	benard		Access-Accept	2026-08-03 14:28:34.120402+00	\N
42	benard		Access-Accept	2026-08-03 14:28:46.736136+00	\N
43	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-03 14:47:32.721001+00	\N
\.


--
-- Data for Name: radreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radreply (id, username, attribute, op, value) FROM stdin;
1214	AE:C1:5C:88:4A:7F	Session-Timeout	:=	393
1215	AE:C1:5C:88:4A:7F	Mikrotik-Rate-Limit	:=	5M/5M
638	Q41@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
639	Q42@cc49de72	Session-Timeout	:=	5022
640	Q42@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
641	Q43@cc49de72	Session-Timeout	:=	37555
642	Q43@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
298	Q1@cc49de72	Mikrotik-Rate-Limit	= 	5M/5M
299	Q1@cc49de72	Session-Timeout	= 	3597
302	Q2@cc49de72	Session-Timeout	:=	3599
303	Q2@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
1216	Martin	Mikrotik-Rate-Limit	= 	15M/15M
1217	Pauline	Mikrotik-Rate-Limit	= 	15M/15M
1218	Hannah	Mikrotik-Rate-Limit	= 	15M/15M
1219	skita	Mikrotik-Rate-Limit	= 	15M/15M
1220	miriam	Mikrotik-Rate-Limit	= 	15M/15M
1221	shadrack	Mikrotik-Rate-Limit	= 	15M/15M
1222	lucia	Mikrotik-Rate-Limit	= 	15M/15M
1223	andrew	Mikrotik-Rate-Limit	= 	15M/15M
1224	bena	Mikrotik-Rate-Limit	= 	15M/15M
1225	susan	Mikrotik-Rate-Limit	= 	15M/15M
1226	george	Mikrotik-Rate-Limit	= 	15M/15M
1227	margaret	Mikrotik-Rate-Limit	= 	15M/15M
1228	serah	Mikrotik-Rate-Limit	= 	15M/15M
1229	joseph	Mikrotik-Rate-Limit	= 	15M/15M
1230	timothy	Mikrotik-Rate-Limit	= 	15M/15M
1231	irene	Mikrotik-Rate-Limit	= 	15M/15M
1232	orpha	Mikrotik-Rate-Limit	= 	15M/15M
1233	albert2	Mikrotik-Rate-Limit	= 	15M/15M
1234	angela	Mikrotik-Rate-Limit	= 	15M/15M
1235	daniel	Mikrotik-Rate-Limit	= 	15M/15M
1236	mikrotiktest2	Mikrotik-Rate-Limit	= 	15M/15M
1237	daniel2	Mikrotik-Rate-Limit	= 	15M/15M
1238	benard	Mikrotik-Group	= 	rl-expired
1239	Jackline	Mikrotik-Group	= 	rl-expired
561	Q3@cc49de72	Session-Timeout	:=	63850
562	Q3@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
563	Q4@cc49de72	Session-Timeout	:=	36334
564	Q4@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
565	Q5@cc49de72	Session-Timeout	:=	13007
566	Q5@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
567	Q6@cc49de72	Session-Timeout	:=	264025
568	Q6@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
569	Q7@cc49de72	Session-Timeout	:=	37684
570	Q7@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
571	Q8@cc49de72	Session-Timeout	:=	103259
572	Q8@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
573	Q9@cc49de72	Session-Timeout	:=	68729
574	Q9@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
575	Q10@cc49de72	Session-Timeout	:=	1765
576	Q10@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
577	Q11@cc49de72	Session-Timeout	:=	28590
578	Q11@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
579	Q12@cc49de72	Session-Timeout	:=	35070
580	Q12@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
581	Q13@cc49de72	Session-Timeout	:=	6664
582	Q13@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
583	Q14@cc49de72	Session-Timeout	:=	69333
584	Q14@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
585	Q15@cc49de72	Session-Timeout	:=	28286
586	Q15@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
587	Q16@cc49de72	Session-Timeout	:=	7797
588	Q16@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
589	Q17@cc49de72	Session-Timeout	:=	54292
590	Q17@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
591	Q18@cc49de72	Session-Timeout	:=	75827
592	Q18@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
593	Q19@cc49de72	Session-Timeout	:=	20895
594	Q19@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
595	Q20@cc49de72	Session-Timeout	:=	9726
596	Q20@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
597	Q21@cc49de72	Session-Timeout	:=	12181
598	Q21@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
599	Q22@cc49de72	Session-Timeout	:=	14646
600	Q22@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
601	Q23@cc49de72	Session-Timeout	:=	55475
602	Q23@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
603	Q24@cc49de72	Session-Timeout	:=	24670
604	Q24@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
605	Q25@cc49de72	Session-Timeout	:=	72275
606	Q25@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
607	Q26@cc49de72	Session-Timeout	:=	40645
608	Q26@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
609	Q27@cc49de72	Session-Timeout	:=	12023
610	Q27@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
611	Q28@cc49de72	Session-Timeout	:=	16188
612	Q28@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
613	Q29@cc49de72	Session-Timeout	:=	42380
614	Q29@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
615	Q30@cc49de72	Session-Timeout	:=	46396
616	Q30@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
617	Q31@cc49de72	Session-Timeout	:=	2186
618	Q31@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
619	Q32@cc49de72	Session-Timeout	:=	14986
620	Q32@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
621	Q33@cc49de72	Session-Timeout	:=	5787
622	Q33@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
623	Q34@cc49de72	Session-Timeout	:=	16189
624	Q34@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
625	Q35@cc49de72	Session-Timeout	:=	29533
626	Q35@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
627	Q36@cc49de72	Session-Timeout	:=	37843
628	Q36@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
629	Q37@cc49de72	Session-Timeout	:=	10715
630	Q37@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
631	Q38@cc49de72	Session-Timeout	:=	6882
632	Q38@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
633	Q39@cc49de72	Session-Timeout	:=	29592
634	Q39@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
635	Q40@cc49de72	Session-Timeout	:=	21937
636	Q40@cc49de72	Mikrotik-Rate-Limit	:=	5M/5M
637	Q41@cc49de72	Session-Timeout	:=	11987
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
58574731-d4d1-4462-8430-faf7849b802e	cc49de72-5ea8-402b-865a-c2fa66698151	signup_bonus	50.0000	\N	\N	\N	\N	50.0000	\N	completed	Welcome bonus on signup	2026-08-03 12:07:38.812032+00
4aa79c48-70a7-4c86-b87f-af336731108b	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	49.0000	\N	completed	SMS sent	2026-08-03 12:08:25.698672+00
b30e76d4-01ae-4ef5-b670-4a07e1b16a7f	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	48.0000	\N	completed	SMS sent	2026-08-03 12:26:25.92259+00
63c9f684-7961-4740-b4a3-cd6f31d839f5	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	47.0000	\N	completed	SMS sent	2026-08-03 12:32:24.593419+00
2d2edeac-e962-4854-a6d7-744925449381	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	46.0000	\N	completed	SMS sent	2026-08-03 12:34:25.303866+00
6eb234a8-aaa2-4f07-9f51-a2036f1f29fe	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	45.0000	\N	completed	SMS sent	2026-08-03 12:47:35.395315+00
0f074012-473d-4ca1-ada7-08d1025512db	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	44.0000	\N	completed	SMS sent	2026-08-03 12:55:19.983873+00
fe7f775f-a017-48cb-b3eb-8120e91a345f	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	43.0000	\N	completed	SMS sent	2026-08-03 13:36:40.023106+00
c455ad1c-1509-441c-904a-7e8bf8da9c53	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	42.0000	\N	completed	SMS sent	2026-08-03 13:38:33.986122+00
9ed088c0-d750-4e50-9ddc-53adc8470a71	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	41.0000	\N	completed	SMS sent	2026-08-03 13:50:43.848124+00
a4ea1654-8c19-4f61-a93f-b54339c6d95d	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	40.0000	\N	completed	SMS sent	2026-08-03 13:57:52.885526+00
94cfef08-cb5f-424e-9a25-22c25f2ea5de	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	39.0000	\N	completed	SMS sent	2026-08-03 13:59:11.882066+00
615bfd67-af7c-4cad-9e6c-3a5c1ec6b7d4	cc49de72-5ea8-402b-865a-c2fa66698151	consumption	-1.0000	\N	\N	\N	\N	38.0000	\N	completed	SMS sent	2026-08-03 14:22:54.953334+00
\.


--
-- Data for Name: sms_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_logs (id, isp_id, recipient, message, gateway, gateway_message_id, status, cost, sent_at) FROM stdin;
065b277d-2733-4306-9e9d-7799c34f7e8a	cc49de72-5ea8-402b-865a-c2fa66698151	254704994652	Your RumaLink verification code is 583698. It expires in 10 minutes. Do not share it.	rumalink	\N	sent	\N	2026-08-03 12:08:25.701146+00
edbc6c36-4b85-4d1a-9bf8-2a0ceae24cf2	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated for Shi.\nIt connects automatically — no login needed.\nExpires: 03 Aug 2026, 16:26\nReceipt: KQO6BL5	rumalink	\N	sent	\N	2026-08-03 12:26:25.924358+00
d3a588c7-9e21-4240-ae61-0d80811ee86c	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated.\nUsername: Q2\nPassword: fe8ba5\nExpires: 03 Aug 2026, 16:32\nReceipt: 087LON2	rumalink	\N	sent	\N	2026-08-03 12:32:24.595295+00
573ea78f-137d-4f36-84cc-b249ce69347c	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated.\nUsername: Q2\nPassword: fe8ba5\nExpires: 03 Aug 2026, 16:34\nReceipt: 0XX7V27	rumalink	\N	sent	\N	2026-08-03 12:34:25.305741+00
c4661474-b80b-460a-9d4b-5ab77dfc0d9e	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated for Shi.\nIt connects automatically — no login needed.\nExpires: 03 Aug 2026, 16:47\nReceipt: UH3131EDLA	rumalink	\N	sent	\N	2026-08-03 12:47:35.397937+00
9a3cc382-f258-415c-bcd3-767a2b75986e	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated.\nUsername: Q2\nPassword: fe8ba5\nExpires: 03 Aug 2026, 16:55\nReceipt: UH3131E6O3	rumalink	\N	sent	\N	2026-08-03 12:55:19.985827+00
a55fb1d9-2e9b-402c-b6a6-de375b73b38f	cc49de72-5ea8-402b-865a-c2fa66698151	254704994652	⚠️ RumaLink: "DandoraPhase3" has switched to the BACKUP link — now on WAN2 (ether1). The main link is down or degraded. Your customers stay online on the backup; we will text you when the main link returns.	rumalink	\N	sent	\N	2026-08-03 13:36:40.025171+00
f5826707-8084-4236-b31f-e75ba4e0c541	cc49de72-5ea8-402b-865a-c2fa66698151	254704994652	✅ RumaLink: "DandoraPhase3" is back on its MAIN link — WAN1 (ether2). The backup uplink is no longer carrying traffic.	rumalink	\N	sent	\N	2026-08-03 13:38:33.988235+00
8b3bc1e0-5314-469b-9101-7213d5a6d848	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated for Shi.\nIt connects automatically — no login needed.\nExpires: 03 Aug 2026, 17:50\nReceipt: UH3131EPNI	rumalink	\N	sent	\N	2026-08-03 13:50:43.850913+00
ddc411d3-e543-4b21-8b2e-9d6a5cf69aad	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated for Shi.\nIt connects automatically — no login needed.\nExpires: 03 Aug 2026, 17:57\nReceipt: UH3131EOEO	rumalink	\N	sent	\N	2026-08-03 13:57:52.887429+00
ee05151f-12d8-4b98-97f1-8687ad831f8f	cc49de72-5ea8-402b-865a-c2fa66698151	254740258495	QuickCoin: 1 Hour activated.\nUsername: Q2\nPassword: fe8ba5\nExpires: 03 Aug 2026, 17:59\nReceipt: UH3131EK3L	rumalink	\N	sent	\N	2026-08-03 13:59:11.884538+00
04b8884a-1c5f-4d3c-93f8-a148ec048577	cc49de72-5ea8-402b-865a-c2fa66698151	0740258495	Dear benard, your QuickCoin internet (15Mbps) has been RENEWED. You are back online. Next due: 3 Sept 2026. Thank you!	rumalink	\N	sent	\N	2026-08-03 14:22:54.955267+00
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
-- Data for Name: system_health; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_health (id, sampled_at, load1, cpu_steal, mem_total_mb, mem_avail_mb, swap_used_mb, disk_pct, freeradius_mb, node_mb, pg_conns, routers_total, routers_down, status) FROM stdin;
1	2026-07-31 09:06:42.342017+00	0.35	0	1906	1363	0	20	56	97	15	1	0	ok
2	2026-07-31 09:07:42.339772+00	0.13	0	1906	1336	0	20	56	91	13	1	0	ok
3	2026-07-31 09:08:10.511475+00	0.45	0	1906	1362	0	20	56	99	15	1	0	ok
4	2026-07-31 09:09:10.508802+00	0.61	0.5	1906	1328	0	20	56	94	16	1	0	ok
5	2026-07-31 09:10:10.509951+00	0.66	0	1906	1324	0	20	56	96	16	1	0	ok
6	2026-07-31 09:11:10.509965+00	0.68	0	1906	1322	0	20	56	98	16	1	0	ok
7	2026-07-31 09:12:10.510309+00	0.32	0.5	1906	1322	0	20	56	101	14	1	0	ok
8	2026-07-31 09:12:37.82225+00	0.28	0	1906	1366	0	20	56	98	15	1	0	ok
9	2026-07-31 09:13:37.820852+00	0.41	0	1906	1350	0	20	56	86	14	1	0	ok
10	2026-07-31 09:14:37.82277+00	0.37	0	1906	1332	0	20	56	94	14	1	0	ok
11	2026-07-31 09:15:37.822235+00	0.49	0	1906	1338	0	20	56	96	15	1	0	ok
12	2026-07-31 09:16:37.82258+00	0.18	0	1906	1331	0	20	56	99	14	1	0	ok
13	2026-07-31 09:17:37.823685+00	0.29	0	1906	1329	0	20	56	95	15	1	0	ok
14	2026-07-31 09:18:37.825006+00	0.42	0	1906	1323	0	20	56	98	15	1	0	ok
15	2026-07-31 09:19:37.825289+00	0.37	0	1906	1326	0	20	56	100	13	1	0	ok
16	2026-07-31 09:20:37.826445+00	0.4	0	1906	1331	0	20	56	101	14	1	0	ok
17	2026-07-31 09:21:37.826756+00	0.4	0	1906	1322	0	20	56	101	13	1	0	ok
18	2026-07-31 09:22:37.826507+00	0.28	0.5	1906	1319	0	20	56	101	13	1	0	ok
19	2026-07-31 09:23:37.828068+00	0.1	0	1906	1308	0	20	56	102	12	1	0	ok
20	2026-07-31 09:24:37.8277+00	0.3	0	1906	1312	0	20	56	102	13	1	0	ok
21	2026-07-31 09:25:37.826858+00	0.47	0	1906	1315	0	20	56	102	13	1	0	ok
22	2026-07-31 09:26:37.830309+00	0.17	0	1906	1335	0	20	56	103	15	1	0	ok
23	2026-07-31 09:27:37.831331+00	0.2	0	1906	1325	0	20	56	103	13	1	0	ok
24	2026-07-31 09:28:37.833626+00	0.34	0	1906	1323	0	20	56	105	13	1	0	ok
25	2026-07-31 09:29:37.829525+00	0.39	0	1906	1320	0	20	56	106	13	1	0	ok
26	2026-07-31 09:30:37.829644+00	0.44	0	1906	1312	0	20	56	105	13	1	0	ok
27	2026-07-31 09:31:37.83215+00	0.16	0	1906	1316	0	20	56	106	13	1	0	ok
28	2026-07-31 09:32:37.831522+00	0.41	0	1906	1329	0	20	56	107	13	1	0	ok
29	2026-07-31 09:33:37.832485+00	0.42	0	1906	1332	0	20	56	107	13	1	0	ok
30	2026-07-31 09:34:37.830862+00	0.29	0	1906	1319	0	20	56	106	13	1	0	ok
31	2026-07-31 09:35:37.832707+00	0.1	0	1906	1310	0	20	56	107	13	1	0	ok
32	2026-07-31 09:36:37.836493+00	0.21	0	1906	1323	0	20	56	101	13	1	0	ok
33	2026-07-31 09:37:37.83475+00	0.3	0	1906	1318	0	20	56	104	13	1	0	ok
34	2026-07-31 09:38:37.833583+00	0.24	0	1906	1314	0	20	56	107	14	1	0	ok
35	2026-07-31 09:39:37.833677+00	0.09	0.5	1906	1326	0	20	56	107	13	1	0	ok
36	2026-07-31 09:40:37.833645+00	0.34	0	1906	1320	0	20	56	107	13	1	0	ok
37	2026-07-31 09:41:37.833435+00	0.39	0	1906	1319	0	20	56	107	13	1	0	ok
38	2026-07-31 09:42:37.834551+00	0.41	0	1906	1318	0	20	56	108	13	1	0	ok
39	2026-07-31 09:43:37.834637+00	0.37	0	1906	1316	0	20	56	108	13	1	0	ok
40	2026-07-31 09:44:37.833565+00	0.13	0	1906	1308	0	20	56	109	13	1	0	ok
41	2026-07-31 09:45:37.837752+00	0.05	0	1906	1319	0	20	56	109	14	1	0	ok
42	2026-07-31 09:46:37.835773+00	0.24	0	1906	1310	0	20	56	109	13	1	0	ok
43	2026-07-31 09:47:37.835749+00	0.26	0	1906	1313	0	20	56	109	13	1	0	ok
44	2026-07-31 09:48:37.837302+00	0.32	0	1906	1311	0	20	56	111	14	1	0	ok
45	2026-07-31 09:49:37.836528+00	0.28	0	1906	1304	0	20	56	111	13	1	0	ok
46	2026-07-31 09:50:37.834777+00	0.24	0	1906	1308	0	20	56	111	13	1	0	ok
47	2026-07-31 09:51:38.900931+00	0.17	0	1906	1318	0	20	56	111	13	1	1	warning
48	2026-07-31 09:52:37.835895+00	0.15	0	1906	1306	0	20	56	111	14	1	1	warning
49	2026-07-31 09:53:37.835099+00	0.28	0	1906	1308	0	20	56	111	13	1	1	warning
50	2026-07-31 09:54:37.836818+00	0.14	0	1906	1309	0	20	56	111	14	1	1	warning
51	2026-07-31 09:55:37.83634+00	0.05	0	1906	1316	0	20	56	111	13	1	1	warning
52	2026-07-31 09:56:37.840087+00	0.11	0	1906	1320	0	20	56	111	14	1	1	warning
53	2026-07-31 09:57:37.841151+00	0.04	0	1906	1306	0	20	56	111	14	1	1	warning
54	2026-07-31 09:58:37.839638+00	0.01	0	1906	1305	0	20	56	111	15	1	1	warning
55	2026-07-31 09:59:38.897671+00	0.27	0	1906	1312	0	20	56	111	12	1	0	ok
56	2026-07-31 10:00:37.84139+00	0.37	0	1906	1313	0	20	56	112	12	1	0	ok
57	2026-07-31 10:01:37.842858+00	0.18	0	1906	1322	0	20	56	111	11	1	0	ok
58	2026-07-31 10:02:37.841845+00	0.06	0	1906	1315	0	20	56	112	12	1	0	ok
59	2026-07-31 10:03:37.842157+00	0.02	0	1906	1310	0	20	56	112	11	1	0	ok
60	2026-07-31 10:04:37.84318+00	0.14	0	1906	1310	0	20	56	112	12	1	0	ok
61	2026-07-31 10:05:37.841615+00	0.14	0	1906	1314	0	20	56	112	12	1	0	ok
62	2026-07-31 10:06:37.843246+00	0.27	0	1906	1310	0	20	56	112	12	1	0	ok
63	2026-07-31 10:07:37.842959+00	0.19	0	1906	1316	0	20	56	112	12	1	0	ok
64	2026-07-31 10:08:37.842428+00	0.07	0	1906	1304	0	20	56	113	11	1	0	ok
65	2026-07-31 10:09:37.844406+00	0.02	0	1906	1305	0	20	56	112	11	1	0	ok
66	2026-07-31 10:10:37.84464+00	0.01	0	1906	1315	0	20	56	113	12	1	0	ok
67	2026-07-31 10:11:37.843046+00	0.07	0	1906	1312	0	20	56	112	10	1	0	ok
68	2026-07-31 10:12:37.841803+00	0.16	0	1906	1309	0	20	56	112	12	1	0	ok
69	2026-07-31 10:13:37.842824+00	0.15	0	1906	1316	0	20	56	112	12	1	0	ok
70	2026-07-31 10:14:37.843071+00	0.14	0	1906	1316	0	20	56	112	13	1	0	ok
71	2026-07-31 10:15:37.845513+00	0.14	0.5	1906	1321	0	20	56	113	12	1	0	ok
72	2026-07-31 10:16:37.843662+00	0.11	0	1906	1312	0	20	56	112	12	1	0	ok
73	2026-07-31 10:17:37.844875+00	0.04	0	1906	1310	0	20	56	113	10	1	0	ok
74	2026-07-31 10:18:37.844642+00	0.17	0	1906	1304	0	20	56	113	11	1	0	ok
75	2026-07-31 10:19:37.844616+00	0.09	0	1906	1316	0	20	56	112	11	1	0	ok
76	2026-07-31 10:20:37.845752+00	0.32	0	1906	1303	0	20	56	113	11	1	0	ok
77	2026-07-31 10:21:37.846631+00	0.12	0.5	1906	1313	0	20	56	112	10	1	0	ok
78	2026-07-31 10:22:37.84726+00	0.04	0	1906	1302	0	20	56	113	10	1	0	ok
79	2026-07-31 10:23:37.845516+00	0.01	0	1906	1319	0	20	56	112	10	1	0	ok
80	2026-07-31 10:24:37.847106+00	0	0	1906	1309	0	20	56	113	10	1	0	ok
81	2026-07-31 10:25:37.84615+00	0	0	1906	1312	0	20	56	112	10	1	0	ok
82	2026-07-31 10:26:37.845201+00	0	0	1906	1313	0	20	56	113	11	1	0	ok
83	2026-07-31 10:27:37.847063+00	0	0	1906	1312	0	20	56	112	11	1	0	ok
84	2026-07-31 10:28:37.846955+00	0	0	1906	1299	0	20	56	113	12	1	0	ok
85	2026-07-31 10:29:37.845221+00	0	0	1906	1300	0	20	56	113	10	0	0	ok
86	2026-07-31 10:30:37.846698+00	0	0	1906	1298	0	20	56	113	10	0	0	ok
87	2026-07-31 10:31:37.846935+00	0	0	1906	1308	0	20	56	113	10	0	0	ok
88	2026-07-31 10:32:37.847896+00	0.03	0	1906	1296	0	20	56	113	10	0	0	ok
89	2026-07-31 10:33:37.849+00	0.11	0	1906	1317	0	20	56	113	11	0	0	ok
90	2026-07-31 10:34:37.84832+00	0.07	0	1906	1308	0	20	56	114	10	0	0	ok
91	2026-07-31 10:35:37.849596+00	0.14	0	1906	1302	0	20	56	114	11	0	0	ok
92	2026-07-31 10:36:37.848506+00	0.05	0	1906	1295	0	20	56	114	11	0	0	ok
93	2026-07-31 10:37:37.847856+00	0.02	0	1906	1291	0	20	56	113	11	0	0	ok
94	2026-07-31 10:38:37.850087+00	0	0	1906	1305	0	20	56	114	11	0	0	ok
95	2026-07-31 10:39:37.849751+00	0	0	1906	1299	0	20	56	113	11	0	0	ok
96	2026-07-31 10:40:37.84918+00	0	0	1906	1292	0	20	56	114	11	0	0	ok
97	2026-07-31 10:41:37.850845+00	0	0	1906	1301	0	20	56	114	12	0	0	ok
98	2026-07-31 10:42:37.851104+00	0.05	0	1906	1299	0	20	56	114	11	0	0	ok
99	2026-07-31 10:43:37.852153+00	0.02	0	1906	1290	0	20	56	115	11	0	0	ok
100	2026-07-31 10:44:37.853333+00	0	0	1906	1298	0	20	56	116	11	0	0	ok
101	2026-07-31 10:45:37.853419+00	0	0	1906	1306	0	20	56	115	11	0	0	ok
102	2026-07-31 10:46:37.852739+00	0	0	1906	1307	0	20	56	115	12	0	0	ok
103	2026-07-31 10:47:37.854358+00	0	0	1906	1298	0	20	56	116	12	0	0	ok
104	2026-07-31 10:48:37.854962+00	0	0	1906	1291	0	20	56	115	11	0	0	ok
105	2026-07-31 10:49:37.853998+00	0	0	1906	1287	0	20	56	115	14	0	0	ok
106	2026-07-31 10:50:37.85274+00	0	0	1906	1308	0	20	56	116	11	0	0	ok
107	2026-07-31 10:51:37.856232+00	0	0	1906	1304	0	20	56	116	11	0	0	ok
108	2026-07-31 10:52:37.855367+00	0	0	1906	1295	0	20	57	115	11	1	0	ok
109	2026-07-31 10:53:37.856262+00	0	0	1906	1306	0	20	57	115	11	1	0	ok
110	2026-07-31 10:54:37.85499+00	0	0.5	1906	1297	0	20	57	116	11	1	0	ok
111	2026-07-31 10:55:37.856577+00	0.05	0	1906	1305	0	20	57	108	12	1	0	ok
112	2026-07-31 10:56:37.859281+00	0.02	0	1906	1293	0	20	57	114	12	1	0	ok
113	2026-07-31 10:57:37.864254+00	0	0	1906	1305	0	20	57	114	11	1	0	ok
114	2026-07-31 10:58:37.863823+00	0.06	0	1906	1282	0	20	57	115	17	1	0	ok
115	2026-07-31 10:59:37.86345+00	0.02	0	1906	1296	0	20	57	115	11	1	0	ok
116	2026-07-31 11:00:37.861802+00	0.09	0	1906	1292	0	20	57	115	12	1	0	ok
117	2026-07-31 11:01:37.862815+00	0.03	0	1906	1306	0	20	57	115	12	1	0	ok
118	2026-07-31 11:02:37.864991+00	0.01	0	1906	1291	0	20	57	115	13	1	0	ok
119	2026-07-31 11:03:37.86304+00	0	0	1906	1292	0	20	57	115	12	1	0	ok
120	2026-07-31 11:04:37.863177+00	0	0	1906	1298	0	20	57	116	12	1	0	ok
121	2026-07-31 11:05:37.864066+00	0	0.5	1906	1303	0	20	57	115	12	1	0	ok
122	2026-07-31 11:06:37.864606+00	0	0	1906	1297	0	20	57	118	14	1	0	ok
123	2026-07-31 11:07:37.864955+00	0	0	1906	1303	0	20	57	116	12	1	0	ok
124	2026-07-31 11:08:37.866779+00	0	0	1906	1291	0	20	57	116	12	1	0	ok
125	2026-07-31 11:09:37.864995+00	0	0	1906	1304	0	20	57	116	11	1	0	ok
126	2026-07-31 11:10:37.868072+00	0.25	0	1906	1288	0	20	57	116	12	1	0	ok
127	2026-07-31 11:11:37.868407+00	0.09	0	1906	1295	0	20	57	116	15	1	0	ok
128	2026-07-31 11:12:37.867431+00	0.03	0	1906	1289	0	20	57	122	11	1	0	ok
129	2026-07-31 11:13:37.869188+00	0.01	0	1906	1293	0	20	57	122	11	1	0	ok
130	2026-07-31 11:14:37.86998+00	0.09	0	1906	1294	0	20	57	122	11	1	0	ok
131	2026-07-31 11:15:37.870899+00	0.03	0	1906	1291	0	20	57	123	12	1	0	ok
132	2026-07-31 11:16:37.870852+00	0.01	0	1906	1296	0	20	57	122	12	1	0	ok
133	2026-07-31 11:17:37.871548+00	0	0	1906	1304	0	20	57	122	11	1	0	ok
134	2026-07-31 11:18:37.870685+00	0	0	1906	1290	0	20	57	123	12	1	0	ok
135	2026-07-31 11:19:37.87289+00	0.24	0	1906	1295	0	20	57	123	11	1	0	ok
136	2026-07-31 11:20:37.869537+00	0.09	0	1906	1294	0	20	57	122	12	1	0	ok
137	2026-07-31 11:21:37.870958+00	0.03	0	1906	1295	0	20	57	123	11	1	0	ok
138	2026-07-31 11:22:37.870877+00	0.01	0	1906	1286	0	20	57	124	11	1	0	ok
139	2026-07-31 11:23:37.874958+00	0	0	1906	1290	0	20	57	124	12	1	0	ok
140	2026-07-31 11:24:37.870887+00	0	0	1906	1293	0	20	57	123	12	1	0	ok
141	2026-07-31 11:25:37.870309+00	0	0	1906	1297	0	20	57	123	12	1	0	ok
142	2026-07-31 11:26:37.871288+00	0	0	1906	1284	0	20	57	124	11	1	0	ok
143	2026-07-31 11:27:37.872964+00	0	0	1906	1299	0	20	57	124	11	1	0	ok
144	2026-07-31 11:28:37.87158+00	0	0	1906	1285	0	20	57	123	11	1	0	ok
145	2026-07-31 11:29:37.873678+00	0	0	1906	1301	0	20	57	124	10	1	0	ok
146	2026-07-31 11:30:37.872715+00	0	0	1906	1294	0	20	57	123	10	1	0	ok
147	2026-07-31 11:31:37.873913+00	0	0	1906	1292	0	20	57	123	10	1	0	ok
148	2026-07-31 11:32:37.87333+00	0.14	0	1906	1289	0	20	57	124	10	1	0	ok
149	2026-07-31 11:33:37.874623+00	0.13	0	1906	1294	0	20	57	123	10	1	0	ok
150	2026-07-31 11:34:15.396266+00	0.15	0.5	1906	1349	0	20	57	99	12	1	0	ok
151	2026-07-31 11:35:15.397868+00	0.22	0	1906	1306	0	20	57	102	15	1	0	ok
152	2026-07-31 11:36:15.397709+00	0.08	0	1906	1303	0	20	57	105	15	1	0	ok
153	2026-07-31 11:37:15.399952+00	0.03	0.5	1906	1297	0	20	57	107	14	1	0	ok
154	2026-07-31 11:38:15.39984+00	0.01	0.49	1906	1298	0	20	57	108	19	1	0	ok
155	2026-07-31 11:39:15.400544+00	0	0	1906	1299	0	20	57	108	18	1	0	ok
156	2026-07-31 11:40:15.401029+00	0	0	1906	1289	0	20	57	109	19	1	0	ok
157	2026-07-31 11:41:15.404201+00	0	0	1906	1302	0	20	57	109	17	1	0	ok
158	2026-07-31 11:42:15.401715+00	0	0	1906	1297	0	20	57	109	16	1	0	ok
159	2026-07-31 11:43:15.401153+00	0	0.5	1906	1296	0	20	57	109	16	1	0	ok
160	2026-07-31 11:44:15.400903+00	0	0	1906	1284	0	20	57	109	19	1	0	ok
161	2026-07-31 11:45:15.400539+00	0.06	0	1906	1290	0	20	57	109	18	1	0	ok
162	2026-07-31 11:46:15.401584+00	0.02	0	1906	1291	0	20	57	109	19	1	0	ok
163	2026-07-31 11:47:15.402179+00	0	0	1906	1292	0	20	57	102	18	1	0	ok
164	2026-07-31 11:48:15.40335+00	0	0.5	1906	1298	0	20	57	104	18	1	0	ok
165	2026-07-31 11:49:15.400566+00	0	0	1906	1297	0	20	57	107	18	1	0	ok
166	2026-07-31 11:50:15.40372+00	0.11	0	1906	1292	0	20	57	110	18	1	0	ok
167	2026-07-31 11:51:15.402962+00	0.04	0	1906	1307	0	20	57	110	15	1	0	ok
168	2026-07-31 11:52:15.403218+00	0.01	0.5	1906	1298	0	20	57	109	18	1	0	ok
169	2026-07-31 11:53:15.402766+00	0	0.5	1906	1294	0	20	57	110	18	1	0	ok
170	2026-07-31 11:53:56.940804+00	0	0	1906	1356	0	20	57	98	12	1	0	ok
171	2026-07-31 11:54:56.940934+00	0	0	1906	1335	0	20	57	94	10	1	0	ok
172	2026-07-31 11:55:56.939889+00	0	0	1906	1330	0	20	57	96	10	1	0	ok
173	2026-07-31 11:56:56.938193+00	0	0	1906	1303	0	20	57	96	10	1	0	ok
174	2026-07-31 11:57:56.940138+00	0	0	1906	1327	0	20	57	98	10	1	0	ok
175	2026-07-31 11:58:56.942519+00	0.03	0	1906	1323	0	20	57	101	11	1	0	ok
176	2026-07-31 11:59:56.942929+00	0.01	0	1906	1334	0	20	57	94	12	1	0	ok
177	2026-07-31 12:00:56.941611+00	0	0	1906	1329	0	20	57	97	10	1	0	ok
178	2026-07-31 12:01:56.940342+00	0	0.5	1906	1330	0	20	57	100	11	1	0	ok
179	2026-07-31 12:02:56.942827+00	0	0	1906	1326	0	20	57	101	11	1	0	ok
180	2026-07-31 12:03:56.946238+00	0	0	1906	1324	0	20	57	102	14	1	0	ok
181	2026-07-31 12:04:56.94513+00	0.03	0	1906	1313	0	20	56	101	12	1	0	ok
182	2026-07-31 12:05:56.946701+00	0.05	0	1906	1316	0	20	56	101	13	1	0	ok
183	2026-07-31 12:06:56.945047+00	0.02	0	1906	1326	0	20	56	102	9	1	0	ok
184	2026-07-31 12:07:56.944605+00	0	0	1906	1315	0	20	56	103	9	1	0	ok
185	2026-07-31 12:08:56.945276+00	0	0	1906	1327	0	20	56	102	10	1	0	ok
186	2026-07-31 12:09:56.946824+00	0	0	1906	1324	0	20	56	103	11	1	0	ok
187	2026-07-31 12:10:56.945314+00	0.04	0	1906	1321	0	20	56	103	13	1	0	ok
188	2026-07-31 12:11:56.945983+00	0.01	0	1906	1320	0	20	56	104	14	1	0	ok
189	2026-07-31 12:12:56.948256+00	0	0	1906	1317	0	20	56	105	10	1	0	ok
190	2026-07-31 12:13:56.947316+00	0	0	1906	1319	0	20	56	106	10	1	0	ok
191	2026-07-31 12:14:20.257674+00	0.08	0	1906	1360	0	20	56	98	12	1	0	ok
192	2026-07-31 12:15:20.255268+00	0.03	0	1906	1323	0	20	56	87	16	1	0	ok
193	2026-07-31 12:16:20.259279+00	0.01	0	1906	1309	0	20	56	97	17	1	0	ok
194	2026-07-31 12:17:20.260108+00	0	0	1906	1294	0	20	56	97	16	1	0	ok
195	2026-07-31 12:17:34.367723+00	0	0.5	1906	1354	0	20	56	99	14	1	0	ok
196	2026-07-31 12:18:34.36825+00	0	0	1906	1317	0	20	56	99	12	1	0	ok
197	2026-07-31 12:19:34.369913+00	0	0	1906	1316	0	20	56	101	12	1	0	ok
198	2026-07-31 12:20:34.368219+00	0	0	1906	1313	0	20	56	104	12	1	0	ok
199	2026-07-31 12:21:34.36983+00	0.06	0	1906	1303	0	20	56	106	12	1	0	ok
200	2026-07-31 12:22:34.369316+00	0.02	0	1906	1317	0	20	56	101	12	1	0	ok
201	2026-07-31 12:23:29.786497+00	0.01	0	1906	1340	0	20	56	99	14	1	0	ok
202	2026-07-31 12:24:29.786096+00	0	0	1906	1311	0	20	56	91	21	1	0	ok
203	2026-07-31 12:25:29.787157+00	0	0	1906	1320	0	20	56	95	15	1	0	ok
204	2026-07-31 12:26:29.787194+00	0.04	0	1906	1307	0	20	56	96	19	1	0	ok
205	2026-07-31 12:27:29.786599+00	0.01	0	1906	1314	0	20	56	99	13	1	0	ok
206	2026-07-31 12:28:29.787636+00	0	0	1906	1314	0	20	56	101	17	1	0	ok
207	2026-07-31 12:29:29.78809+00	0	0	1906	1317	0	20	56	95	16	1	0	ok
208	2026-07-31 12:30:29.789098+00	0	0	1906	1312	0	20	56	97	17	1	0	ok
209	2026-07-31 12:31:29.788263+00	0.08	0	1906	1307	0	20	56	100	17	1	0	ok
210	2026-07-31 12:32:29.790249+00	0.19	0	1906	1302	0	20	56	102	17	1	0	ok
211	2026-07-31 12:33:29.791011+00	0.11	0	1906	1305	0	20	56	102	17	1	0	ok
212	2026-07-31 12:34:29.792787+00	0.04	0.5	1906	1306	0	20	56	101	17	1	0	ok
213	2026-07-31 12:35:29.791311+00	0.06	0	1906	1302	0	20	56	105	16	1	0	ok
214	2026-07-31 12:36:29.791308+00	0.02	0	1906	1292	0	20	56	106	16	1	0	ok
215	2026-07-31 12:37:29.792298+00	0	0	1906	1297	0	20	56	106	16	1	0	ok
216	2026-07-31 12:38:29.791945+00	0.04	0	1906	1306	0	20	56	106	14	1	0	ok
217	2026-07-31 12:39:29.792178+00	0.01	0	1906	1297	0	20	56	106	14	1	0	ok
218	2026-07-31 12:40:29.79096+00	0	0	1906	1311	0	20	56	106	15	1	0	ok
219	2026-07-31 12:41:29.790496+00	0	0	1906	1307	0	20	56	107	16	1	0	ok
220	2026-07-31 12:42:29.790883+00	0	0	1906	1309	0	20	56	108	16	1	0	ok
221	2026-07-31 12:43:29.791125+00	0	0	1906	1301	0	20	56	107	16	1	0	ok
222	2026-07-31 12:44:29.790487+00	0	0	1906	1303	0	20	56	107	16	1	0	ok
223	2026-07-31 12:45:29.792969+00	0	0	1906	1307	0	20	56	100	16	1	0	ok
224	2026-07-31 12:46:29.795236+00	0	0	1906	1315	0	20	56	102	16	1	0	ok
225	2026-07-31 12:47:29.793636+00	0.08	0	1906	1307	0	20	56	105	16	1	0	ok
226	2026-07-31 12:48:29.793846+00	0.03	0	1906	1313	0	20	56	107	13	1	0	ok
227	2026-07-31 12:49:29.794383+00	0.01	0	1906	1306	0	20	56	108	13	1	0	ok
228	2026-07-31 12:50:29.797313+00	0	0	1906	1313	0	20	56	107	13	1	0	ok
229	2026-07-31 12:51:29.793441+00	0	0	1906	1300	0	20	56	107	13	1	0	ok
230	2026-07-31 12:52:29.793939+00	0	0	1906	1302	0	20	56	107	13	1	0	ok
231	2026-07-31 12:53:29.803701+00	0.23	0	1906	1256	0	20	56	109	13	1	0	ok
232	2026-07-31 12:54:29.794315+00	0.08	0	1906	1292	0	20	56	107	13	1	0	ok
233	2026-07-31 12:55:29.795142+00	0.03	0	1906	1298	0	20	56	108	12	1	0	ok
234	2026-07-31 12:56:29.794837+00	0.01	0	1906	1296	0	20	56	109	12	1	0	ok
235	2026-07-31 12:57:29.796282+00	0	0	1906	1292	0	20	56	117	13	1	0	ok
236	2026-07-31 12:58:29.796437+00	0	0	1906	1292	0	20	56	117	12	1	0	ok
237	2026-07-31 12:59:29.796908+00	0	0	1906	1295	0	20	56	117	13	1	0	ok
238	2026-07-31 13:00:29.79634+00	0	0	1906	1306	0	20	56	117	14	1	0	ok
239	2026-07-31 13:01:29.795461+00	0	0	1906	1296	0	20	56	117	16	1	0	ok
240	2026-07-31 13:02:29.797442+00	0	0	1906	1286	0	20	56	118	17	1	0	ok
241	2026-07-31 13:03:29.797758+00	0	0	1906	1297	0	20	56	118	17	1	0	ok
242	2026-07-31 13:04:29.800052+00	0	0	1906	1295	0	20	56	118	17	1	0	ok
243	2026-07-31 13:05:29.799299+00	0	0	1906	1298	0	20	56	119	17	1	0	ok
244	2026-07-31 13:06:29.800925+00	0	0	1906	1295	0	20	56	118	18	1	0	ok
245	2026-07-31 13:07:29.799698+00	0	0	1906	1289	0	20	56	118	18	1	0	ok
246	2026-07-31 13:08:29.799004+00	0	0	1906	1294	0	20	56	120	17	1	0	ok
247	2026-07-31 13:09:29.800066+00	0.06	0	1906	1295	0	20	57	119	17	1	0	ok
248	2026-07-31 13:10:29.800619+00	0.02	0	1906	1291	0	20	57	118	17	1	0	ok
249	2026-07-31 13:11:29.802111+00	0.01	0	1906	1297	0	20	57	118	17	1	0	ok
250	2026-07-31 13:12:29.804547+00	0	0	1906	1299	0	20	57	119	17	1	0	ok
251	2026-07-31 13:13:29.804142+00	0	0	1906	1279	0	20	57	118	18	1	0	ok
252	2026-07-31 13:14:29.803711+00	0	0	1906	1297	0	20	57	118	13	1	0	ok
253	2026-07-31 13:15:29.80466+00	0	0	1906	1290	0	20	57	119	14	1	0	ok
254	2026-07-31 13:16:29.806111+00	0.03	0	1906	1299	0	20	57	120	13	1	0	ok
255	2026-07-31 13:17:29.807297+00	0.04	0	1906	1302	0	20	57	119	13	1	0	ok
256	2026-07-31 13:18:29.807232+00	0.01	0	1906	1297	0	20	57	119	13	1	0	ok
257	2026-07-31 13:19:29.807877+00	0	0	1906	1290	0	20	57	119	15	1	0	ok
258	2026-07-31 13:20:29.806967+00	0	0	1906	1297	0	20	57	121	15	1	0	ok
259	2026-07-31 13:21:29.808272+00	0	0	1906	1300	0	20	57	119	15	1	0	ok
260	2026-07-31 13:22:29.809436+00	0	0	1906	1294	0	20	57	120	18	1	0	ok
261	2026-07-31 13:23:29.810286+00	0	0	1906	1280	0	20	57	120	17	1	0	ok
262	2026-07-31 13:24:29.812895+00	0.03	0	1906	1287	0	20	57	120	18	1	0	ok
263	2026-07-31 13:25:29.813057+00	0.07	0	1906	1291	0	20	57	120	17	1	0	ok
264	2026-07-31 13:26:29.812456+00	0.02	0	1906	1288	0	20	57	121	17	1	0	ok
265	2026-07-31 13:27:29.81262+00	0.01	0	1906	1278	0	20	57	120	18	1	0	ok
266	2026-07-31 13:28:29.814513+00	0	0	1906	1292	0	20	57	122	17	1	0	ok
267	2026-07-31 13:29:29.823247+00	0	0	1906	1292	0	20	57	121	18	1	0	ok
268	2026-07-31 13:30:29.817305+00	0	0	1906	1297	0	20	57	121	17	1	0	ok
269	2026-07-31 13:31:29.820272+00	0	0	1906	1290	0	20	57	121	17	1	0	ok
270	2026-07-31 13:32:29.81997+00	0	0	1906	1292	0	20	57	121	17	1	0	ok
271	2026-07-31 13:33:29.819279+00	0	0	1906	1290	0	20	57	121	17	1	0	ok
272	2026-07-31 13:34:29.821087+00	0	0	1906	1304	0	20	57	115	17	1	0	ok
273	2026-07-31 13:35:29.820161+00	0.07	0	1906	1300	0	20	57	117	17	1	0	ok
274	2026-07-31 13:36:29.819524+00	0.08	0	1906	1293	0	20	57	119	17	1	0	ok
275	2026-07-31 13:37:29.820575+00	0.03	0	1906	1283	0	20	57	120	17	1	0	ok
276	2026-07-31 13:38:29.819811+00	0.01	0	1906	1287	0	20	57	121	17	1	0	ok
277	2026-07-31 13:39:29.823222+00	0.04	0	1906	1299	0	20	57	120	17	1	0	ok
278	2026-07-31 13:40:29.824109+00	0.01	0	1906	1289	0	20	57	120	17	1	0	ok
279	2026-07-31 13:41:29.824876+00	0	0	1906	1290	0	20	57	121	17	1	0	ok
280	2026-07-31 13:42:29.828307+00	0	0	1906	1300	0	20	57	121	16	1	0	ok
281	2026-07-31 13:43:29.826863+00	0	0	1906	1293	0	20	57	121	17	1	0	ok
282	2026-07-31 13:44:29.825541+00	0	0	1906	1291	0	20	57	120	16	1	0	ok
283	2026-07-31 13:45:29.827578+00	0	0	1906	1297	0	20	57	120	17	1	0	ok
284	2026-07-31 13:46:29.827048+00	0.53	0	1906	1283	0	20	57	120	17	1	0	ok
285	2026-07-31 13:47:29.830522+00	0.22	0	1906	1292	0	20	57	120	17	1	0	ok
286	2026-07-31 13:48:29.833122+00	0.61	0	1906	1293	0	20	57	121	19	1	0	ok
287	2026-07-31 13:49:29.834257+00	0.43	0	1906	1287	0	20	57	121	18	1	0	ok
288	2026-07-31 13:50:29.831895+00	0.84	0	1906	1289	0	20	57	122	19	1	0	ok
289	2026-07-31 13:51:29.83275+00	0.31	0	1906	1288	0	20	57	121	18	1	0	ok
290	2026-07-31 13:52:29.833275+00	0.19	0	1906	1284	0	20	57	121	19	1	0	ok
291	2026-07-31 13:53:29.833728+00	0.07	0	1906	1287	0	20	57	121	17	1	0	ok
292	2026-07-31 13:54:29.833658+00	0.02	0	1906	1291	0	20	57	121	17	1	0	ok
293	2026-07-31 13:55:29.833773+00	0.01	0	1906	1294	0	20	57	121	16	1	0	ok
294	2026-07-31 13:56:29.833868+00	0	0	1906	1294	0	20	57	120	18	1	0	ok
295	2026-07-31 13:57:29.832568+00	0.04	0	1906	1296	0	20	57	120	15	1	0	ok
296	2026-07-31 13:58:29.834606+00	0.01	0	1906	1286	0	20	57	120	16	1	0	ok
297	2026-07-31 13:59:29.834953+00	0	0	1906	1291	0	20	57	121	17	1	0	ok
298	2026-07-31 14:00:29.836189+00	0	0	1906	1287	0	20	57	120	18	1	0	ok
299	2026-07-31 14:01:29.836596+00	0	0	1906	1285	0	20	57	120	17	1	0	ok
300	2026-07-31 14:02:29.835135+00	0.05	0	1906	1299	0	20	57	120	16	1	0	ok
301	2026-07-31 14:03:29.833987+00	0.07	0	1906	1295	0	20	57	120	11	1	0	ok
302	2026-07-31 14:04:29.835528+00	0.02	0	1906	1290	0	20	57	121	15	1	0	ok
303	2026-07-31 14:05:29.834927+00	0.01	0	1906	1297	0	20	57	121	16	1	0	ok
304	2026-07-31 14:06:29.835455+00	0	0	1906	1295	0	20	57	121	17	1	0	ok
305	2026-07-31 14:07:29.836715+00	0	0	1906	1282	0	20	57	121	17	1	0	ok
306	2026-07-31 14:08:29.835463+00	0	0	1906	1294	0	20	57	120	18	1	0	ok
307	2026-07-31 14:09:29.835008+00	0	0	1906	1284	0	20	57	120	18	1	0	ok
308	2026-07-31 14:10:29.837556+00	0	0	1906	1289	0	20	57	120	17	1	0	ok
309	2026-07-31 14:11:29.836256+00	0	0	1906	1292	0	20	57	121	18	1	0	ok
310	2026-07-31 14:12:29.837792+00	0	0	1906	1281	0	20	57	121	19	1	0	ok
311	2026-07-31 14:13:29.83585+00	0	0	1906	1297	0	20	57	121	16	1	0	ok
312	2026-07-31 14:14:29.836441+00	0	0	1906	1293	0	20	57	120	18	1	0	ok
313	2026-07-31 14:15:29.839866+00	0	0	1906	1302	0	20	57	120	14	1	0	ok
314	2026-07-31 14:16:29.837144+00	0	0	1906	1289	0	20	57	120	16	1	0	ok
315	2026-07-31 14:17:29.837138+00	0	0	1906	1293	0	20	57	121	18	1	0	ok
316	2026-07-31 14:18:29.837366+00	0	0	1906	1292	0	20	57	121	18	1	0	ok
317	2026-07-31 14:19:29.837818+00	0	0	1906	1289	0	20	57	121	17	1	0	ok
318	2026-07-31 14:20:29.837397+00	0	0	1906	1288	0	20	57	120	18	1	0	ok
319	2026-07-31 14:21:29.836918+00	0	0.5	1906	1293	0	20	57	120	17	1	0	ok
320	2026-07-31 14:22:29.838481+00	0.03	0	1906	1293	0	20	57	120	19	1	0	ok
321	2026-07-31 14:23:29.837479+00	0.07	0	1906	1288	0	20	57	120	18	1	0	ok
322	2026-07-31 14:24:29.83887+00	0.02	0	1906	1285	0	20	57	120	18	1	0	ok
323	2026-07-31 14:25:29.838683+00	0.01	0	1906	1290	0	20	57	120	17	1	0	ok
324	2026-07-31 14:26:29.839123+00	0	0	1906	1285	0	20	57	120	16	1	0	ok
325	2026-07-31 14:27:29.837627+00	0	0	1906	1294	0	20	57	121	16	1	0	ok
326	2026-07-31 14:28:29.838317+00	0	0	1906	1291	0	20	57	121	14	1	0	ok
327	2026-07-31 14:29:29.840194+00	0	0	1906	1301	0	20	57	121	14	1	0	ok
328	2026-07-31 14:30:29.838727+00	0.03	0	1906	1285	0	20	57	121	18	1	0	ok
329	2026-07-31 14:31:29.838426+00	0.01	0	1906	1286	0	20	57	121	17	1	0	ok
330	2026-07-31 14:32:29.838589+00	0.04	0	1906	1281	0	20	57	121	18	1	0	ok
331	2026-07-31 14:33:29.83839+00	0.01	0	1906	1280	0	20	57	121	17	1	0	ok
332	2026-07-31 14:34:29.839104+00	0	1	1906	1275	0	20	57	122	18	1	0	ok
333	2026-07-31 14:35:29.838475+00	0	0	1906	1282	0	20	57	121	18	1	0	ok
334	2026-07-31 14:36:29.839195+00	0	0	1906	1280	0	20	57	121	19	1	0	ok
335	2026-07-31 14:37:29.837656+00	0	0	1906	1291	0	20	57	121	18	1	0	ok
336	2026-07-31 14:38:29.838118+00	0	0	1906	1281	0	20	57	121	19	1	0	ok
337	2026-07-31 14:39:29.838165+00	0	0	1906	1286	0	20	57	121	18	1	0	ok
338	2026-07-31 14:40:29.839638+00	0.04	0	1906	1291	0	20	57	122	19	1	0	ok
339	2026-07-31 14:41:29.837957+00	0.11	0	1906	1291	0	20	57	121	17	1	0	ok
340	2026-07-31 14:42:29.837979+00	0.04	0	1906	1291	0	20	57	122	18	1	0	ok
341	2026-07-31 14:43:29.83981+00	0.09	0	1906	1289	0	20	57	121	17	1	0	ok
342	2026-07-31 14:44:29.839114+00	0.03	0	1906	1292	0	20	57	122	18	1	0	ok
343	2026-07-31 14:45:29.837915+00	0.01	0	1906	1288	0	20	57	122	17	1	0	ok
344	2026-07-31 14:46:29.840485+00	0	0	1906	1289	0	20	57	122	18	1	0	ok
345	2026-07-31 14:47:29.84071+00	0	0	1906	1288	0	20	57	122	18	1	0	ok
346	2026-07-31 14:48:29.839403+00	0	0	1906	1277	0	20	57	122	19	1	0	ok
347	2026-07-31 14:49:29.838773+00	0	0	1906	1291	0	20	57	122	18	1	0	ok
348	2026-07-31 14:50:29.839342+00	0	0	1906	1280	0	20	57	123	18	1	0	ok
349	2026-07-31 14:51:29.839637+00	0	0	1906	1291	0	20	57	123	17	1	0	ok
350	2026-07-31 14:52:29.839946+00	0	0	1906	1281	0	20	57	122	18	1	0	ok
351	2026-07-31 14:53:29.838717+00	0	0	1906	1291	0	20	57	122	17	1	0	ok
352	2026-07-31 14:54:29.846355+00	0	0	1906	1286	0	20	57	122	18	1	0	ok
353	2026-07-31 14:55:29.847086+00	0	0	1906	1281	0	20	57	123	17	1	0	ok
354	2026-07-31 14:56:29.846924+00	0	0	1906	1280	0	20	57	122	18	1	0	ok
355	2026-07-31 14:57:29.847321+00	0	0	1906	1293	0	20	57	122	17	1	0	ok
356	2026-07-31 14:58:29.851752+00	0	0	1906	1289	0	20	57	122	19	1	0	ok
357	2026-07-31 14:59:29.848829+00	0.21	0	1906	1292	0	20	57	122	18	1	0	ok
358	2026-07-31 15:00:29.849148+00	0.2	0	1906	1279	0	20	57	122	19	1	0	ok
359	2026-07-31 15:01:29.849932+00	0.07	0	1906	1284	0	20	57	123	17	1	0	ok
360	2026-07-31 15:02:29.847629+00	0.02	0	1906	1284	0	20	57	122	16	1	0	ok
361	2026-07-31 15:03:29.847084+00	0.01	0	1906	1285	0	20	57	122	17	1	0	ok
362	2026-07-31 15:04:29.847387+00	0.04	0	1906	1288	0	20	57	123	18	1	0	ok
363	2026-07-31 15:05:29.846989+00	0.01	0	1906	1292	0	20	57	122	17	1	0	ok
364	2026-07-31 15:06:29.848359+00	0	0	1906	1289	0	20	57	122	18	1	0	ok
365	2026-07-31 15:07:29.848491+00	0	0	1906	1281	0	20	57	122	17	1	0	ok
366	2026-07-31 15:08:29.849421+00	0	0	1906	1276	0	20	57	122	19	1	0	ok
367	2026-07-31 15:09:29.849502+00	0	0	1906	1281	0	20	57	122	18	1	0	ok
368	2026-07-31 15:10:29.851573+00	0	0.51	1906	1290	0	20	57	122	19	1	0	ok
369	2026-07-31 15:11:29.853323+00	0	0	1906	1291	0	20	57	122	18	1	0	ok
370	2026-07-31 15:12:29.855612+00	0	0	1906	1286	0	20	57	122	18	1	0	ok
371	2026-07-31 15:13:29.85575+00	0	0	1906	1279	0	20	57	122	18	1	0	ok
372	2026-07-31 15:14:29.853916+00	0	0	1906	1289	0	20	57	123	19	1	0	ok
373	2026-07-31 15:15:29.855023+00	0	0	1906	1286	0	20	57	122	18	1	0	ok
374	2026-07-31 15:16:29.854625+00	0	0	1906	1280	0	20	57	122	19	1	0	ok
375	2026-07-31 15:17:29.852974+00	0	0	1906	1278	0	20	57	122	18	1	0	ok
376	2026-07-31 15:18:29.854221+00	0.32	0	1906	1285	0	20	57	122	18	1	0	ok
377	2026-07-31 15:19:29.853761+00	0.11	0	1906	1278	0	20	57	122	18	1	0	ok
378	2026-07-31 15:20:29.855365+00	0.83	0	1906	1280	0	20	57	123	18	1	0	ok
379	2026-07-31 15:21:29.856935+00	0.57	0	1906	1292	0	20	57	123	18	1	0	ok
380	2026-07-31 15:22:29.862014+00	0.21	0	1906	1278	0	20	57	123	17	1	0	ok
381	2026-07-31 15:23:29.859675+00	0.44	0	1906	1284	0	20	57	123	17	1	0	ok
382	2026-07-31 15:24:29.861317+00	0.16	0	1906	1287	0	20	57	123	17	1	0	ok
383	2026-07-31 15:25:29.859626+00	0.06	0	1906	1280	0	20	57	124	18	1	0	ok
384	2026-07-31 15:26:29.859937+00	0.02	0	1906	1285	0	20	57	123	16	1	0	ok
385	2026-07-31 15:27:29.860747+00	0.22	0	1906	1289	0	20	57	123	17	1	0	ok
386	2026-07-31 15:28:29.862291+00	0.08	0	1906	1289	0	20	57	123	16	1	0	ok
387	2026-07-31 15:29:29.862993+00	0.03	0	1906	1284	0	20	57	123	16	1	0	ok
388	2026-07-31 15:30:29.864062+00	0.54	0	1906	1284	0	20	57	123	17	1	0	ok
389	2026-07-31 15:31:29.864063+00	0.2	0	1906	1295	0	20	57	124	13	1	0	ok
390	2026-07-31 15:32:29.865535+00	0.07	0	1906	1292	0	20	57	123	16	1	0	ok
391	2026-07-31 15:33:29.868574+00	0.29	0	1906	1281	0	20	57	123	18	1	0	ok
392	2026-07-31 15:34:29.865682+00	0.1	0.5	1906	1287	0	20	57	123	17	1	0	ok
393	2026-07-31 15:35:29.867148+00	0.08	0	1906	1278	0	20	57	123	17	1	0	ok
394	2026-07-31 15:36:29.866221+00	0.35	0	1906	1285	0	20	57	123	16	1	0	ok
395	2026-07-31 15:37:29.867478+00	0.18	0	1906	1293	0	20	57	123	17	1	0	ok
396	2026-07-31 15:38:29.86885+00	0.06	0	1906	1288	0	20	57	124	19	1	0	ok
397	2026-07-31 15:39:29.868071+00	0.13	0	1906	1282	0	20	57	123	17	1	0	ok
398	2026-07-31 15:40:29.872547+00	0.08	0	1906	1278	0	20	57	124	19	1	0	ok
399	2026-07-31 15:41:29.872402+00	0.03	0.5	1906	1291	0	20	57	123	18	1	0	ok
400	2026-07-31 15:42:29.871638+00	0.32	0	1906	1279	0	20	57	124	19	1	0	ok
401	2026-07-31 15:43:29.873756+00	0.38	0.5	1906	1275	0	20	57	124	18	1	0	ok
402	2026-07-31 15:44:29.873063+00	0.14	0	1906	1282	0	20	57	124	17	1	0	ok
403	2026-07-31 15:45:29.875918+00	0.05	0	1906	1275	0	20	57	123	17	1	0	ok
404	2026-07-31 15:46:29.872905+00	0.06	0	1906	1280	0	20	57	123	18	1	0	ok
405	2026-07-31 15:47:29.873473+00	0.28	0	1906	1278	0	20	57	123	18	1	0	ok
406	2026-07-31 15:48:29.873852+00	0.52	0	1906	1277	0	20	57	124	19	1	0	ok
407	2026-07-31 15:49:29.875312+00	0.3	0.5	1906	1289	0	20	57	124	18	1	0	ok
408	2026-07-31 15:50:29.875068+00	0.11	0	1906	1289	0	20	57	124	18	1	0	ok
409	2026-07-31 15:51:29.87897+00	0.14	0	1906	1280	0	20	57	124	18	1	0	ok
410	2026-07-31 15:52:29.879066+00	0.1	0	1906	1283	0	20	57	124	19	1	0	ok
411	2026-07-31 15:53:29.878044+00	0.46	0	1906	1280	0	20	57	124	18	1	0	ok
412	2026-07-31 15:54:29.878847+00	0.17	0	1906	1282	0	20	57	125	19	1	0	ok
413	2026-07-31 15:55:29.877709+00	0.32	0	1906	1280	0	20	57	123	18	1	0	ok
414	2026-07-31 15:56:29.880241+00	0.33	0	1906	1284	0	20	57	123	18	1	0	ok
415	2026-07-31 15:57:29.88527+00	0.12	0	1906	1289	0	20	57	123	17	1	0	ok
416	2026-07-31 15:58:29.881018+00	0.31	0	1906	1276	0	20	57	124	18	1	0	ok
417	2026-07-31 15:59:29.882673+00	0.11	0	1906	1295	0	20	57	123	14	1	0	ok
418	2026-07-31 16:00:29.883583+00	0.67	0	1906	1296	0	20	57	123	14	1	0	ok
419	2026-07-31 16:01:29.882927+00	0.25	0.5	1906	1285	0	20	57	124	18	1	0	ok
420	2026-07-31 16:02:29.883698+00	0.39	0	1906	1286	0	20	57	124	18	1	0	ok
421	2026-07-31 16:03:29.883623+00	0.28	0	1906	1292	0	20	57	123	15	1	0	ok
422	2026-07-31 16:04:29.886897+00	0.1	0	1906	1298	0	20	57	123	13	1	0	ok
423	2026-07-31 16:05:29.884721+00	0.62	0	1906	1299	0	20	57	124	11	1	0	ok
424	2026-07-31 16:06:29.884695+00	0.49	0	1906	1299	0	20	57	124	11	1	0	ok
425	2026-07-31 16:07:29.887384+00	0.55	0	1906	1294	0	20	57	125	13	1	0	ok
426	2026-07-31 16:08:29.888467+00	0.62	0	1906	1296	0	20	57	125	13	1	0	ok
427	2026-07-31 16:09:29.887182+00	0.28	0	1906	1293	0	20	57	124	12	1	0	ok
428	2026-07-31 16:10:29.887418+00	0.1	0	1906	1298	0	20	57	115	14	1	0	ok
429	2026-07-31 16:11:29.889919+00	0.3	0	1906	1287	0	20	57	118	18	1	0	ok
430	2026-07-31 16:12:29.889797+00	0.32	0	1906	1281	0	20	57	120	18	1	0	ok
431	2026-07-31 16:13:29.888872+00	0.19	0	1906	1283	0	20	57	122	17	1	0	ok
432	2026-07-31 16:14:29.889855+00	0.38	0	1906	1283	0	20	57	122	19	1	0	ok
433	2026-07-31 16:15:29.890036+00	0.14	0	1906	1289	0	20	57	122	16	1	0	ok
434	2026-07-31 16:16:29.89039+00	0.21	0	1906	1290	0	20	57	122	16	1	0	ok
435	2026-07-31 16:17:29.891347+00	0.07	0	1906	1287	0	20	57	122	16	1	0	ok
436	2026-07-31 16:18:29.892904+00	0.29	0	1906	1283	0	20	57	122	18	1	0	ok
437	2026-07-31 16:19:29.892629+00	0.42	0	1906	1289	0	20	57	122	18	1	0	ok
438	2026-07-31 16:20:29.89354+00	0.31	0	1906	1291	0	20	57	122	17	1	0	ok
439	2026-07-31 16:21:29.894814+00	0.11	0	1906	1288	0	20	57	123	17	1	0	ok
440	2026-07-31 16:22:29.894459+00	0.3	0	1906	1283	0	20	57	122	18	1	0	ok
441	2026-07-31 16:23:29.893694+00	0.27	0	1906	1283	0	20	57	122	17	1	0	ok
442	2026-07-31 16:24:29.89373+00	0.31	0	1906	1280	0	20	57	123	19	1	0	ok
443	2026-07-31 16:25:29.894269+00	0.31	0	1906	1276	0	20	57	122	16	1	0	ok
444	2026-07-31 16:26:29.897525+00	0.11	0	1906	1289	0	20	57	124	15	1	0	ok
445	2026-07-31 16:27:29.898022+00	0.3	0	1906	1290	0	20	57	124	14	1	0	ok
446	2026-07-31 16:28:29.89665+00	0.43	0	1906	1282	0	20	57	123	14	1	0	ok
447	2026-07-31 16:29:29.897871+00	0.15	0	1906	1280	0	20	57	123	16	1	0	ok
448	2026-07-31 16:30:29.89743+00	0.06	0	1906	1290	0	20	57	123	17	1	0	ok
449	2026-07-31 16:31:29.895563+00	0.28	0	1906	1280	0	20	57	123	17	1	0	ok
450	2026-07-31 16:32:29.896939+00	0.21	0	1906	1279	0	20	57	122	18	1	0	ok
451	2026-07-31 16:33:29.897495+00	0.07	0	1906	1280	0	20	57	123	16	1	0	ok
452	2026-07-31 16:34:29.897403+00	0.29	0	1906	1284	0	20	57	124	12	1	0	ok
453	2026-07-31 16:35:29.898704+00	0.27	0	1906	1282	0	20	57	123	17	1	0	ok
454	2026-07-31 16:36:29.897789+00	0.36	0	1906	1284	0	20	57	123	18	1	0	ok
455	2026-07-31 16:37:29.897775+00	0.39	0	1906	1292	0	20	57	122	17	1	0	ok
456	2026-07-31 16:38:29.898927+00	0.14	0	1906	1282	0	20	57	123	18	1	0	ok
457	2026-07-31 16:39:29.896773+00	0.05	0	1906	1277	0	20	57	123	17	1	0	ok
458	2026-07-31 16:40:29.896548+00	0.33	0	1906	1287	0	20	57	123	13	1	0	ok
459	2026-07-31 16:41:29.89978+00	0.12	0	1906	1288	0	20	57	123	15	1	0	ok
460	2026-07-31 16:42:29.898877+00	0.04	0	1906	1287	0	20	57	123	19	1	0	ok
461	2026-07-31 16:43:29.896618+00	0.01	0	1906	1285	0	20	57	123	17	1	0	ok
462	2026-07-31 16:44:29.900282+00	0	0	1906	1288	0	20	57	123	19	1	0	ok
463	2026-07-31 16:45:29.900776+00	0.42	0	1906	1283	0	20	57	123	18	1	0	ok
464	2026-07-31 16:46:29.900114+00	0.18	0	1906	1283	0	20	57	123	19	1	0	ok
465	2026-07-31 16:47:29.898852+00	0.07	0	1906	1279	0	20	57	123	18	1	0	ok
466	2026-07-31 16:47:33.170184+00	0.06	0	1906	1351	0	20	57	100	12	1	0	ok
467	2026-07-31 16:48:33.167682+00	0.2	0	1906	1323	0	20	57	92	10	1	0	ok
468	2026-07-31 16:49:33.168736+00	0.22	0	1906	1311	0	20	57	93	10	1	0	ok
469	2026-07-31 16:50:33.165519+00	0.08	0	1906	1312	0	20	57	96	10	1	0	ok
470	2026-07-31 16:51:33.171512+00	0.12	0	1906	1305	0	20	57	98	11	1	0	ok
471	2026-07-31 16:52:18.167794+00	0.24	0	1906	1335	0	20	57	99	12	1	0	ok
472	2026-07-31 16:53:18.165279+00	0.13	0	1906	1306	0	20	57	90	17	1	0	ok
473	2026-07-31 16:54:18.166691+00	0.05	0	1906	1309	0	20	57	94	18	1	0	ok
474	2026-07-31 16:55:18.166509+00	0.02	0	1906	1305	0	20	57	96	16	1	0	ok
475	2026-07-31 16:56:18.167706+00	0	0	1906	1290	0	20	57	103	18	1	0	ok
476	2026-07-31 16:57:18.166899+00	0	0	1906	1307	0	20	57	98	16	1	0	ok
477	2026-07-31 16:58:18.167131+00	0	0	1906	1297	0	20	57	100	15	1	0	ok
478	2026-07-31 16:59:18.168619+00	0.25	0	1906	1303	0	20	57	103	14	1	0	ok
479	2026-07-31 17:00:18.168729+00	0.46	0	1906	1300	0	20	57	104	13	1	0	ok
480	2026-07-31 17:01:18.168243+00	0.41	0	1906	1311	0	20	57	106	11	1	0	ok
481	2026-07-31 17:02:18.170384+00	0.15	0	1906	1300	0	20	57	104	13	1	0	ok
482	2026-07-31 17:02:48.587381+00	0.17	0.5	1906	1341	0	20	57	99	12	1	0	ok
483	2026-07-31 17:03:48.586847+00	0.06	0	1906	1327	0	20	57	91	10	1	0	ok
484	2026-07-31 17:04:48.584865+00	0.02	0	1906	1324	0	20	57	93	10	1	0	ok
485	2026-07-31 17:05:48.586723+00	0.18	0	1906	1324	0	20	57	96	10	1	0	ok
486	2026-07-31 17:06:48.589841+00	0.15	0	1906	1320	0	20	57	98	11	1	0	ok
487	2026-07-31 17:06:51.286998+00	0.15	0	1906	1332	0	20	57	98	12	1	0	ok
488	2026-07-31 17:07:51.285294+00	0.05	0	1906	1330	0	20	57	91	10	1	0	ok
489	2026-07-31 17:08:51.285485+00	0.02	0	1906	1314	0	20	57	94	12	1	0	ok
490	2026-07-31 17:09:51.28529+00	0	0	1906	1317	0	20	57	98	12	1	0	ok
491	2026-07-31 17:10:51.28897+00	0	0	1906	1321	0	20	57	102	12	1	0	ok
492	2026-07-31 17:11:51.287317+00	0	0	1906	1303	0	20	57	110	17	1	0	ok
493	2026-07-31 17:12:51.288438+00	0	0	1906	1305	0	20	57	112	11	1	0	ok
494	2026-07-31 17:13:51.288345+00	0	0	1906	1309	0	20	57	112	12	1	0	ok
495	2026-07-31 17:14:51.288507+00	0	0	1906	1305	0	20	57	113	13	1	0	ok
496	2026-07-31 17:15:51.289535+00	0	0	1906	1313	0	20	57	113	12	1	0	ok
497	2026-07-31 17:16:51.289113+00	0	0	1906	1304	0	20	57	113	12	1	0	ok
498	2026-07-31 17:17:51.291163+00	0.17	0	1906	1306	0	20	57	113	12	1	0	ok
499	2026-07-31 17:18:51.307306+00	0.14	0	1906	1289	0	20	57	114	14	1	0	ok
500	2026-07-31 17:19:51.291827+00	0.08	0	1906	1308	0	20	57	114	13	1	0	ok
501	2026-07-31 17:20:51.290555+00	0.03	0	1906	1306	0	20	57	114	13	1	0	ok
502	2026-07-31 17:21:51.290309+00	0.01	0	1906	1304	0	20	57	114	11	1	0	ok
503	2026-07-31 17:22:51.292088+00	0	0	1906	1311	0	20	57	114	13	1	0	ok
504	2026-07-31 17:23:51.290324+00	0	0	1906	1309	0	20	57	115	11	1	0	ok
505	2026-07-31 17:24:51.294749+00	0.19	0	1906	1312	0	20	57	114	13	1	0	ok
506	2026-07-31 17:25:37.905026+00	0.08	0	1906	1334	0	20	57	98	12	1	0	ok
507	2026-07-31 17:26:37.905243+00	0.03	0	1906	1310	0	20	57	95	12	1	0	ok
508	2026-07-31 17:27:37.90441+00	0.07	0	1906	1319	0	20	57	101	13	1	0	ok
509	2026-07-31 17:28:37.90488+00	0.11	0.5	1906	1300	0	20	57	112	12	1	0	ok
510	2026-07-31 17:29:37.90651+00	0.04	0	1906	1299	0	20	57	108	14	1	0	ok
511	2026-07-31 17:30:37.903916+00	0.01	0	1906	1297	0	20	57	111	12	1	0	ok
512	2026-07-31 17:31:37.906161+00	0	0	1906	1292	0	20	57	113	12	1	0	ok
513	2026-07-31 17:32:37.905899+00	0.16	0	1906	1303	0	20	57	114	12	1	0	ok
514	2026-07-31 17:33:37.906553+00	0.06	0	1906	1301	0	20	57	113	12	1	0	ok
515	2026-07-31 17:34:37.906163+00	0.08	0	1906	1299	0	20	57	114	12	1	0	ok
516	2026-07-31 17:35:37.908347+00	0.13	0	1906	1299	0	20	57	114	9	1	0	ok
517	2026-07-31 17:36:37.908217+00	0.08	0	1906	1286	0	20	57	115	15	1	0	ok
518	2026-07-31 17:37:37.909175+00	0.03	0	1906	1299	0	20	57	115	10	1	0	ok
519	2026-07-31 17:38:37.907781+00	0.01	0	1906	1302	0	20	57	115	10	1	0	ok
520	2026-07-31 17:39:37.908494+00	0	0	1906	1303	0	20	57	115	11	1	0	ok
521	2026-07-31 17:40:37.90795+00	0	0	1906	1298	0	20	57	116	11	1	0	ok
522	2026-07-31 17:41:37.908616+00	0	0	1906	1295	0	20	57	116	14	1	0	ok
523	2026-07-31 17:42:37.906174+00	0	0	1906	1302	0	20	57	116	10	1	0	ok
524	2026-07-31 17:43:37.910761+00	0	0	1906	1295	0	20	57	116	13	1	0	ok
525	2026-07-31 17:44:16.93027+00	0.05	0	1906	1333	0	20	57	98	12	1	0	ok
526	2026-07-31 17:45:16.934149+00	0.02	0	1906	1310	0	20	57	91	17	1	0	ok
527	2026-07-31 17:46:16.932596+00	0	0	1906	1302	0	20	57	98	18	1	0	ok
528	2026-07-31 17:47:16.932517+00	0	0	1906	1306	0	20	57	100	18	1	0	ok
529	2026-07-31 17:48:16.935426+00	0	0	1906	1287	0	20	57	102	17	1	0	ok
530	2026-07-31 17:48:27.725766+00	0	0	1906	1338	0	20	57	98	12	1	0	ok
531	2026-07-31 17:49:27.725502+00	0	0	1906	1314	0	20	57	93	17	1	0	ok
532	2026-07-31 17:50:27.727189+00	0	0	1906	1300	0	20	57	97	17	1	0	ok
533	2026-07-31 17:51:27.726559+00	0	0	1906	1301	0	20	57	97	18	1	0	ok
534	2026-07-31 17:52:27.726955+00	0	0	1906	1302	0	20	57	101	18	1	0	ok
535	2026-07-31 17:53:27.72869+00	0	0	1906	1301	0	20	57	96	19	1	0	ok
536	2026-07-31 17:54:27.7273+00	0	0	1906	1301	0	20	57	97	19	1	0	ok
537	2026-07-31 17:55:27.728427+00	0	0	1906	1306	0	20	57	100	17	1	0	ok
538	2026-07-31 17:56:27.726703+00	0	0	1906	1300	0	20	57	102	16	1	0	ok
539	2026-07-31 17:57:27.727008+00	0	0.5	1906	1308	0	20	57	103	16	1	0	ok
540	2026-07-31 17:58:27.726643+00	0	0	1906	1301	0	20	57	103	14	1	0	ok
541	2026-07-31 17:59:27.726916+00	0	0	1906	1302	0	20	57	103	16	1	0	ok
542	2026-07-31 18:00:28.623045+00	0.1	0	1906	1335	0	20	57	98	12	1	0	ok
543	2026-07-31 18:01:28.621726+00	0.1	0	1906	1310	0	20	57	98	15	1	0	ok
544	2026-07-31 18:02:28.623771+00	0.04	0	1906	1298	0	20	57	99	16	1	0	ok
545	2026-07-31 18:03:28.621652+00	0.01	0	1906	1302	0	20	57	106	16	1	0	ok
546	2026-07-31 18:04:28.622504+00	0	0	1906	1285	0	20	57	102	19	1	0	ok
547	2026-07-31 18:05:28.623379+00	0	0	1906	1294	0	20	57	106	17	1	0	ok
548	2026-07-31 18:06:28.623002+00	0	0	1906	1285	0	20	57	108	19	1	0	ok
549	2026-07-31 18:07:28.624556+00	0	0	1906	1297	0	20	57	110	17	1	0	ok
550	2026-07-31 18:08:28.625905+00	0	0	1906	1297	0	20	57	109	18	1	0	ok
551	2026-07-31 18:08:31.060862+00	0	0.5	1906	1337	0	20	57	99	12	1	0	ok
552	2026-07-31 18:09:31.040996+00	0	0	1906	1312	0	20	57	96	14	1	0	ok
553	2026-07-31 18:10:31.039885+00	0.04	0	1906	1300	0	20	57	99	10	1	0	ok
554	2026-07-31 18:11:31.03925+00	0.01	0	1906	1300	0	20	57	103	10	1	0	ok
555	2026-07-31 18:12:31.03922+00	0	0	1906	1296	0	20	57	105	10	1	0	ok
556	2026-07-31 18:13:31.042602+00	0	0	1906	1305	0	20	57	101	10	1	0	ok
557	2026-07-31 18:14:31.042596+00	0	0.5	1906	1302	0	20	57	104	10	1	0	ok
558	2026-07-31 18:15:31.045459+00	0	0	1906	1298	0	20	57	105	10	1	0	ok
559	2026-07-31 18:16:31.042629+00	0	0	1906	1306	0	20	57	107	10	1	0	ok
560	2026-07-31 18:17:31.043257+00	0	0	1906	1282	0	20	57	106	19	1	0	ok
561	2026-07-31 18:18:31.043372+00	0	0	1906	1283	0	20	57	107	9	1	0	ok
562	2026-07-31 18:19:31.042354+00	0	0	1906	1290	0	20	57	107	8	1	0	ok
563	2026-07-31 18:20:31.042534+00	0	0	1906	1291	0	20	57	107	20	1	0	ok
564	2026-07-31 18:21:31.040601+00	0	0	1906	1293	0	20	57	104	11	0	0	ok
565	2026-07-31 18:22:31.041549+00	0	0	1906	1302	0	20	57	105	11	0	0	ok
566	2026-07-31 18:23:31.043218+00	0.07	0	1906	1299	0	20	57	107	11	0	0	ok
567	2026-07-31 18:24:31.044762+00	0.02	0	1906	1297	0	20	57	110	15	0	0	ok
568	2026-07-31 18:25:31.044478+00	0.01	0	1906	1284	0	20	57	110	12	0	0	ok
569	2026-07-31 18:26:31.045072+00	0	0.5	1906	1285	0	20	57	110	11	0	0	ok
570	2026-07-31 18:27:31.045105+00	0	0	1906	1289	0	20	58	111	11	1	0	ok
571	2026-07-31 18:28:31.049371+00	0	0	1906	1283	0	20	58	110	11	1	0	ok
572	2026-07-31 18:29:31.049392+00	0	0	1906	1294	0	20	58	111	11	1	0	ok
573	2026-07-31 18:30:31.049053+00	0	0	1906	1285	0	20	58	111	11	1	0	ok
574	2026-07-31 18:31:31.118423+00	0	0.5	1906	1286	0	20	58	104	15	1	0	ok
575	2026-07-31 18:32:31.13164+00	0	0	1906	1290	0	20	58	106	13	1	0	ok
576	2026-07-31 18:33:31.132945+00	0	0	1906	1287	0	20	58	107	13	1	0	ok
577	2026-07-31 18:34:31.130384+00	0	0	1906	1291	0	20	58	108	13	1	0	ok
578	2026-07-31 18:35:31.1295+00	0.03	0	1906	1290	0	20	58	108	12	1	0	ok
579	2026-07-31 18:36:31.130968+00	0.01	0	1906	1288	0	20	58	109	12	1	0	ok
580	2026-07-31 18:37:31.129668+00	0	0	1906	1294	0	20	58	111	11	1	0	ok
581	2026-07-31 18:38:31.1326+00	0	0	1906	1292	0	20	58	111	12	1	0	ok
582	2026-07-31 18:39:31.13081+00	0	0	1906	1288	0	20	58	112	18	1	0	ok
583	2026-07-31 18:40:31.130431+00	0	0	1906	1287	0	20	58	112	11	1	0	ok
584	2026-07-31 18:41:31.132015+00	0	0	1906	1293	0	20	58	112	13	1	0	ok
585	2026-07-31 18:42:31.131461+00	0	0	1906	1284	0	20	58	119	11	1	0	ok
586	2026-07-31 18:43:31.131835+00	0	0	1906	1284	0	20	58	120	15	1	0	ok
587	2026-07-31 18:44:31.133611+00	0	0	1906	1278	0	20	58	119	11	1	0	ok
588	2026-07-31 18:45:31.13315+00	0	0	1906	1288	0	20	58	119	11	1	0	ok
589	2026-07-31 18:46:31.133691+00	0	0	1906	1278	0	20	58	119	11	1	0	ok
590	2026-07-31 18:47:31.132091+00	0	0	1906	1291	0	20	58	119	11	1	0	ok
591	2026-07-31 18:48:31.132237+00	0	0	1906	1284	0	20	58	120	11	1	0	ok
592	2026-07-31 18:49:31.132395+00	0	0	1906	1293	0	20	58	120	11	1	0	ok
593	2026-07-31 18:50:31.135503+00	0	0	1906	1299	0	20	58	120	11	1	0	ok
594	2026-07-31 18:51:31.134541+00	0	0	1906	1291	0	20	58	119	11	1	0	ok
595	2026-07-31 18:52:31.133953+00	0	0	1906	1294	0	20	58	119	11	1	0	ok
596	2026-07-31 18:53:31.133731+00	0	0	1906	1292	0	20	58	119	11	1	0	ok
597	2026-07-31 18:54:31.137079+00	0	0	1906	1291	0	20	58	119	11	1	0	ok
598	2026-07-31 18:55:31.133375+00	0	0	1906	1292	0	20	58	119	11	1	0	ok
599	2026-07-31 18:56:31.133518+00	0	0	1906	1290	0	20	58	120	11	1	0	ok
600	2026-07-31 18:57:31.133627+00	0	0.5	1906	1295	0	20	58	120	11	1	0	ok
601	2026-07-31 18:58:31.134155+00	0	0	1906	1283	0	20	58	121	11	1	0	ok
602	2026-07-31 18:59:31.135097+00	0.08	0	1906	1293	0	20	58	119	11	1	0	ok
603	2026-07-31 19:00:31.134712+00	0.03	0	1906	1280	0	20	58	120	11	1	0	ok
604	2026-07-31 19:01:31.133662+00	0.01	0	1906	1295	0	20	58	119	11	1	0	ok
605	2026-07-31 19:02:31.137164+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
606	2026-07-31 19:03:31.137226+00	0	0	1906	1284	0	20	58	119	11	1	0	ok
607	2026-07-31 19:04:31.1368+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
608	2026-07-31 19:05:31.140644+00	0	0	1906	1281	0	20	58	119	11	1	0	ok
609	2026-07-31 19:06:31.138176+00	0	0	1906	1280	0	20	58	120	11	1	0	ok
610	2026-07-31 19:07:31.135557+00	0	0	1906	1283	0	20	58	121	11	1	0	ok
611	2026-07-31 19:08:31.135613+00	0	0	1906	1290	0	20	58	120	11	1	0	ok
612	2026-07-31 19:09:31.13894+00	0	0	1906	1286	0	20	58	120	11	1	0	ok
613	2026-07-31 19:10:31.137995+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
614	2026-07-31 19:11:31.136083+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
615	2026-07-31 19:12:31.137336+00	0	0	1906	1284	0	20	58	121	11	1	0	ok
616	2026-07-31 19:13:31.137579+00	0	0	1906	1291	0	20	58	121	11	1	0	ok
617	2026-07-31 19:14:31.137495+00	0.03	0	1906	1281	0	20	58	122	11	1	0	ok
618	2026-07-31 19:15:31.138681+00	0.01	0	1906	1286	0	20	58	121	11	1	0	ok
619	2026-07-31 19:16:31.139841+00	0	0	1906	1281	0	20	58	122	12	1	0	ok
620	2026-07-31 19:17:31.140812+00	0	0	1906	1296	0	20	58	122	11	1	0	ok
621	2026-07-31 19:18:31.140668+00	0	0	1906	1282	0	20	58	122	11	1	0	ok
622	2026-07-31 19:19:31.139668+00	0	0	1906	1282	0	20	58	122	11	1	0	ok
623	2026-07-31 19:20:31.140539+00	0	0	1906	1293	0	20	58	122	11	1	0	ok
624	2026-07-31 19:21:31.140228+00	0	0	1906	1278	0	20	58	122	10	1	0	ok
625	2026-07-31 19:22:31.141617+00	0	0	1906	1285	0	20	58	122	10	1	0	ok
626	2026-07-31 19:23:31.140954+00	0	0	1906	1285	0	20	58	121	10	1	0	ok
627	2026-07-31 19:24:31.141951+00	0	0	1906	1284	0	20	58	122	11	1	0	ok
628	2026-07-31 19:25:31.140751+00	0	0	1906	1272	0	20	58	121	10	1	0	ok
629	2026-07-31 19:26:31.14181+00	0	0	1906	1279	0	20	58	121	11	1	0	ok
630	2026-07-31 19:27:31.142993+00	0	0	1906	1280	0	20	58	121	10	1	0	ok
631	2026-07-31 19:28:31.143829+00	0	0	1906	1281	0	20	58	122	10	1	0	ok
632	2026-07-31 19:29:31.141533+00	0	0	1906	1272	0	20	58	121	10	1	0	ok
633	2026-07-31 19:30:31.147409+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
634	2026-07-31 19:31:31.144602+00	0	0	1906	1287	0	20	58	121	11	1	0	ok
635	2026-07-31 19:32:31.147847+00	0	0	1906	1281	0	20	58	121	10	1	0	ok
636	2026-07-31 19:33:31.146304+00	0	0	1906	1279	0	20	58	122	10	1	0	ok
637	2026-07-31 19:34:31.14796+00	0	0	1906	1287	0	20	58	121	10	1	0	ok
638	2026-07-31 19:35:31.14894+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
639	2026-07-31 19:36:31.148283+00	0	0	1906	1282	0	20	58	122	10	1	0	ok
640	2026-07-31 19:37:31.147455+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
641	2026-07-31 19:38:31.147664+00	0	0	1906	1283	0	20	58	121	10	1	0	ok
642	2026-07-31 19:39:31.147831+00	0	0	1906	1284	0	20	58	122	10	1	0	ok
643	2026-07-31 19:40:31.147945+00	0	0	1906	1289	0	20	58	121	10	1	0	ok
644	2026-07-31 19:41:31.1478+00	0	0	1906	1294	0	20	58	122	10	1	0	ok
645	2026-07-31 19:42:31.151097+00	0	0.5	1906	1289	0	20	58	122	10	1	0	ok
646	2026-07-31 19:43:31.150483+00	0	0	1906	1293	0	20	58	121	10	1	0	ok
647	2026-07-31 19:44:31.15179+00	0	0	1906	1294	0	20	58	122	10	1	0	ok
648	2026-07-31 19:45:31.148858+00	0	0	1906	1288	0	20	58	122	10	1	0	ok
649	2026-07-31 19:46:31.149402+00	0	0	1906	1278	0	20	58	122	10	1	0	ok
650	2026-07-31 19:47:31.148927+00	0	0	1906	1282	0	20	58	122	11	1	0	ok
651	2026-07-31 19:48:31.148894+00	0	0	1906	1289	0	20	58	122	11	1	0	ok
652	2026-07-31 19:49:31.14907+00	0	0	1906	1286	0	20	58	122	11	1	0	ok
653	2026-07-31 19:50:31.149824+00	0	0	1906	1294	0	20	58	122	10	1	0	ok
654	2026-07-31 19:51:31.150859+00	0	0	1906	1279	0	20	58	122	11	1	0	ok
655	2026-07-31 19:52:31.155801+00	0	0	1906	1278	0	20	58	121	14	1	0	ok
656	2026-07-31 19:53:31.1547+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
657	2026-07-31 19:54:31.155563+00	0	0	1906	1288	0	20	58	122	10	1	0	ok
658	2026-07-31 19:55:31.155782+00	0	0	1906	1287	0	20	58	121	10	1	0	ok
659	2026-07-31 19:56:31.156514+00	0	0.5	1906	1286	0	20	58	121	10	1	0	ok
660	2026-07-31 19:57:31.155607+00	0	0	1906	1285	0	20	58	122	9	1	0	ok
661	2026-07-31 19:58:31.155327+00	0	0	1906	1282	0	20	58	123	10	1	0	ok
662	2026-07-31 19:59:31.155304+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
663	2026-07-31 20:00:31.154814+00	0	0	1906	1278	0	20	58	121	10	1	0	ok
664	2026-07-31 20:01:31.156702+00	0	0	1906	1270	0	20	58	122	10	1	0	ok
665	2026-07-31 20:02:31.158376+00	0	0	1906	1286	0	20	58	122	10	1	0	ok
666	2026-07-31 20:03:31.160241+00	0	0	1906	1279	0	20	58	122	10	1	0	ok
667	2026-07-31 20:04:31.161772+00	0	0	1906	1285	0	20	58	122	10	1	0	ok
668	2026-07-31 20:05:31.158973+00	0	0	1906	1284	0	20	58	122	11	1	0	ok
669	2026-07-31 20:06:31.159779+00	0	0	1906	1281	0	20	58	122	11	1	0	ok
670	2026-07-31 20:07:31.161163+00	0	0	1906	1278	0	20	58	122	11	1	0	ok
671	2026-07-31 20:08:31.161052+00	0	0	1906	1275	0	20	58	125	11	1	0	ok
672	2026-07-31 20:09:31.161244+00	0	0	1906	1280	0	20	58	125	11	1	0	ok
673	2026-07-31 20:10:31.162272+00	0	0	1906	1280	0	20	58	125	11	1	0	ok
674	2026-07-31 20:11:31.163438+00	0.16	0	1906	1278	0	20	58	125	12	1	0	ok
675	2026-07-31 20:12:31.163178+00	0.06	0	1906	1274	0	20	58	124	12	1	0	ok
676	2026-07-31 20:13:31.162492+00	0.02	0	1906	1288	0	20	58	125	12	1	0	ok
677	2026-07-31 20:14:31.162962+00	0	0	1906	1278	0	20	58	126	12	1	0	ok
678	2026-07-31 20:15:31.162037+00	0	0	1906	1292	0	20	58	125	12	1	0	ok
679	2026-07-31 20:16:31.163842+00	0	0	1906	1286	0	20	58	125	11	1	0	ok
680	2026-07-31 20:17:31.163281+00	0	0	1906	1293	0	20	58	117	11	1	0	ok
681	2026-07-31 20:18:31.163755+00	0	0	1906	1292	0	20	58	118	12	1	0	ok
682	2026-07-31 20:19:31.164514+00	0	0	1906	1278	0	20	58	118	12	1	0	ok
683	2026-07-31 20:20:31.163344+00	0	0	1906	1294	0	20	58	119	12	1	0	ok
684	2026-07-31 20:21:31.162275+00	0	0	1906	1284	0	20	58	120	12	1	0	ok
685	2026-07-31 20:22:31.164804+00	0	0	1906	1280	0	20	58	121	12	1	0	ok
686	2026-07-31 20:23:31.164503+00	0	0	1906	1276	0	20	58	123	12	1	0	ok
687	2026-07-31 20:24:31.167639+00	0	0	1906	1276	0	20	58	122	12	1	0	ok
688	2026-07-31 20:25:31.164724+00	0	0	1906	1280	0	20	58	123	12	1	0	ok
689	2026-07-31 20:26:31.167811+00	0	0	1906	1269	0	20	58	123	12	1	0	ok
690	2026-07-31 20:27:31.167677+00	0	0	1906	1266	0	20	58	124	11	1	0	ok
691	2026-07-31 20:28:31.169699+00	0	0	1906	1271	0	20	58	124	10	1	0	ok
692	2026-07-31 20:29:31.170789+00	0	0	1906	1271	0	20	58	124	10	1	0	ok
693	2026-07-31 20:30:31.16989+00	0	0	1906	1267	0	20	58	124	10	1	0	ok
694	2026-07-31 20:31:31.172897+00	0	0	1906	1272	0	20	58	124	10	1	0	ok
695	2026-07-31 20:32:31.170586+00	0.08	0	1906	1274	0	20	58	124	10	1	0	ok
696	2026-07-31 20:33:31.169474+00	0.03	0	1906	1285	0	20	58	124	10	1	0	ok
697	2026-07-31 20:34:31.171847+00	0.01	0.5	1906	1268	0	20	58	124	10	1	0	ok
698	2026-07-31 20:35:31.171777+00	0.26	0	1906	1281	0	20	58	124	10	1	0	ok
699	2026-07-31 20:36:31.172532+00	0.09	0	1906	1284	0	20	58	124	10	1	0	ok
700	2026-07-31 20:37:31.170988+00	0.22	0	1906	1286	0	20	58	124	10	1	0	ok
701	2026-07-31 20:38:31.17558+00	0.45	0	1906	1292	0	20	58	124	10	1	0	ok
702	2026-07-31 20:39:31.173634+00	0.49	0	1906	1289	0	20	58	124	10	1	0	ok
703	2026-07-31 20:40:31.177654+00	0.18	0	1906	1280	0	20	58	125	10	1	0	ok
704	2026-07-31 20:41:31.17761+00	0.14	0	1906	1279	0	20	58	124	10	1	0	ok
705	2026-07-31 20:42:31.176666+00	0.13	0	1906	1282	0	20	58	124	10	1	0	ok
706	2026-07-31 20:43:31.178658+00	0.05	0	1906	1283	0	20	58	124	10	1	0	ok
707	2026-07-31 20:44:31.178056+00	0.02	0	1906	1284	0	20	58	124	10	1	0	ok
708	2026-07-31 20:45:31.178793+00	0	0	1906	1287	0	20	58	124	10	1	0	ok
709	2026-07-31 20:46:31.179169+00	0	0	1906	1270	0	20	58	124	10	1	0	ok
710	2026-07-31 20:47:31.179801+00	0	0	1906	1287	0	20	58	124	10	1	0	ok
711	2026-07-31 20:48:31.180224+00	0	0	1906	1276	0	20	58	124	10	1	0	ok
712	2026-07-31 20:49:31.18188+00	0.05	0	1906	1279	0	20	58	124	10	1	0	ok
713	2026-07-31 20:50:31.179552+00	0.02	0	1906	1274	0	20	58	124	10	1	0	ok
714	2026-07-31 20:51:31.18023+00	0	0	1906	1272	0	20	58	124	10	1	0	ok
715	2026-07-31 20:52:31.179561+00	0	0.5	1906	1278	0	20	58	124	10	1	0	ok
716	2026-07-31 20:53:31.18185+00	0	0	1906	1287	0	20	58	124	10	1	0	ok
717	2026-07-31 20:54:31.180565+00	0	0	1906	1274	0	20	58	124	10	1	0	ok
718	2026-07-31 20:55:31.17989+00	0	0	1906	1282	0	20	58	124	10	1	0	ok
719	2026-07-31 20:56:31.1798+00	0	0.5	1906	1276	0	20	58	124	10	1	0	ok
720	2026-07-31 20:57:31.181842+00	0	0	1906	1283	0	20	58	124	10	1	0	ok
721	2026-07-31 20:58:31.179779+00	0	0	1906	1280	0	20	58	125	10	1	0	ok
722	2026-07-31 20:59:31.180351+00	0	0	1906	1282	0	20	58	124	10	1	0	ok
723	2026-07-31 21:00:31.180311+00	0.08	0	1906	1279	0	20	58	124	10	1	0	ok
724	2026-07-31 21:01:31.18003+00	0.03	0	1906	1285	0	20	58	125	10	1	0	ok
725	2026-07-31 21:02:31.179492+00	0.01	0	1906	1273	0	20	58	125	10	1	0	ok
726	2026-07-31 21:03:31.180192+00	0	0	1906	1270	0	20	58	124	10	1	0	ok
727	2026-07-31 21:04:31.180368+00	0.16	0	1906	1273	0	20	58	125	10	1	0	ok
728	2026-07-31 21:05:31.179379+00	0.06	0	1906	1281	0	20	58	125	10	1	0	ok
729	2026-07-31 21:06:31.179446+00	0.05	0.5	1906	1283	0	20	58	125	10	1	0	ok
730	2026-07-31 21:07:31.180449+00	0.02	0	1906	1276	0	20	58	125	10	1	0	ok
731	2026-07-31 21:08:31.179863+00	0	0	1906	1275	0	20	58	125	10	1	0	ok
732	2026-07-31 21:09:31.183419+00	0.15	0	1906	1278	0	20	58	125	10	1	0	ok
733	2026-07-31 21:10:31.180217+00	0.05	0	1906	1275	0	20	58	125	10	1	0	ok
734	2026-07-31 21:11:31.179562+00	0.02	0	1906	1285	0	20	58	125	10	1	0	ok
735	2026-07-31 21:12:31.179102+00	0	0	1906	1271	0	20	58	125	10	1	0	ok
736	2026-07-31 21:13:31.182695+00	0.16	0	1906	1283	0	20	58	124	10	1	0	ok
737	2026-07-31 21:14:31.182544+00	0.14	0	1906	1282	0	20	58	125	10	1	0	ok
738	2026-07-31 21:15:31.182844+00	0.05	0	1906	1294	0	20	58	125	10	1	0	ok
739	2026-07-31 21:16:31.186975+00	0.02	0	1906	1277	0	20	58	124	10	1	0	ok
740	2026-07-31 21:17:31.183178+00	0	0	1906	1277	0	20	58	125	10	1	0	ok
741	2026-07-31 21:18:31.182721+00	0	0	1906	1281	0	20	58	124	10	1	0	ok
742	2026-07-31 21:19:31.183075+00	0	0	1906	1282	0	20	58	125	10	1	0	ok
743	2026-07-31 21:20:31.183376+00	0	0	1906	1282	0	20	58	126	10	1	0	ok
744	2026-07-31 21:21:31.184529+00	0	0	1906	1272	0	20	58	126	10	1	0	ok
745	2026-07-31 21:22:31.185136+00	0	0	1906	1270	0	20	58	125	10	1	0	ok
746	2026-07-31 21:23:31.185228+00	0	0	1906	1281	0	20	58	125	10	1	0	ok
747	2026-07-31 21:24:31.186062+00	0	0	1906	1283	0	20	58	125	10	1	0	ok
748	2026-07-31 21:25:31.188671+00	0	0	1906	1282	0	20	58	125	10	1	0	ok
749	2026-07-31 21:26:31.189032+00	0	0	1906	1270	0	20	58	125	10	1	0	ok
750	2026-07-31 21:27:31.18747+00	0	0	1906	1283	0	20	58	125	10	1	0	ok
751	2026-07-31 21:28:31.188593+00	0	0	1906	1267	0	20	58	125	10	1	0	ok
752	2026-07-31 21:29:31.190814+00	0	0	1906	1277	0	20	58	125	10	1	0	ok
753	2026-07-31 21:30:31.193434+00	0	0	1906	1273	0	20	58	125	10	1	0	ok
754	2026-07-31 21:31:31.192104+00	0	0	1906	1286	0	20	58	125	10	1	0	ok
755	2026-07-31 21:32:31.191805+00	0	0	1906	1279	0	20	58	125	10	1	0	ok
756	2026-07-31 21:33:31.190601+00	0	0	1906	1279	0	20	58	125	10	1	0	ok
757	2026-07-31 21:34:31.192906+00	0	0	1906	1281	0	20	58	125	10	1	0	ok
758	2026-07-31 21:35:31.190922+00	0	0	1906	1281	0	20	58	125	10	1	0	ok
759	2026-07-31 21:36:31.192296+00	0	0	1906	1271	0	20	58	126	10	1	0	ok
760	2026-07-31 21:37:31.190641+00	0	0	1906	1266	0	20	58	125	10	1	0	ok
761	2026-07-31 21:38:31.192647+00	0.19	0	1906	1271	0	20	58	125	10	1	0	ok
762	2026-07-31 21:39:31.193423+00	0.51	0	1906	1276	0	20	58	126	10	1	0	ok
763	2026-07-31 21:40:31.192289+00	0.46	0	1906	1280	0	20	58	125	10	1	0	ok
764	2026-07-31 21:41:31.190796+00	0.25	0	1906	1279	0	20	58	125	10	1	0	ok
765	2026-07-31 21:42:31.191287+00	0.09	0	1906	1272	0	20	58	126	10	1	0	ok
766	2026-07-31 21:43:31.191712+00	0.03	0	1906	1283	0	20	58	125	10	1	0	ok
767	2026-07-31 21:44:31.191539+00	0.01	0	1906	1281	0	20	58	126	11	1	0	ok
768	2026-07-31 21:45:31.191082+00	0	0	1906	1291	0	20	58	125	11	1	0	ok
769	2026-07-31 21:46:31.192602+00	0	0	1906	1283	0	20	58	125	11	1	0	ok
770	2026-07-31 21:47:31.193607+00	0.06	0	1906	1294	0	20	58	125	11	1	0	ok
771	2026-07-31 21:48:31.195548+00	0.26	0	1906	1273	0	20	58	125	11	1	0	ok
772	2026-07-31 21:49:31.194847+00	0.09	0	1906	1273	0	20	58	126	11	1	0	ok
773	2026-07-31 21:50:31.195483+00	0.03	0	1906	1280	0	20	58	125	11	1	0	ok
774	2026-07-31 21:51:31.196755+00	0.01	0	1906	1277	0	20	58	125	11	1	0	ok
775	2026-07-31 21:52:31.195529+00	0	0	1906	1276	0	20	58	126	11	1	0	ok
776	2026-07-31 21:53:31.197235+00	0	0	1906	1280	0	20	58	126	11	1	0	ok
777	2026-07-31 21:54:31.196333+00	0	0.5	1906	1277	0	20	58	125	11	1	0	ok
778	2026-07-31 21:55:31.196741+00	0	0	1906	1272	0	20	58	126	11	1	0	ok
779	2026-07-31 21:56:31.197498+00	0.34	0	1906	1276	0	20	58	125	11	1	0	ok
780	2026-07-31 21:57:31.197157+00	0.12	0.5	1906	1267	0	20	58	125	11	1	0	ok
781	2026-07-31 21:58:31.19784+00	0.04	0	1906	1264	0	20	58	125	11	1	0	ok
782	2026-07-31 21:59:31.19794+00	0.01	0.51	1906	1272	0	20	58	125	11	1	0	ok
783	2026-07-31 22:00:31.197647+00	0.54	0	1906	1274	0	20	58	125	11	1	0	ok
784	2026-07-31 22:01:31.197661+00	0.2	0	1906	1277	0	20	58	125	11	1	0	ok
785	2026-07-31 22:02:31.198665+00	0.07	0	1906	1282	0	20	58	125	11	1	0	ok
786	2026-07-31 22:03:31.199731+00	0.02	0	1906	1278	0	20	58	126	15	1	0	ok
787	2026-07-31 22:04:31.199646+00	0.44	0	1906	1275	0	20	58	125	11	1	0	ok
788	2026-07-31 22:05:31.199894+00	0.16	0.5	1906	1281	0	20	58	126	11	1	0	ok
789	2026-07-31 22:06:31.200784+00	0.3	0	1906	1275	0	20	58	126	11	1	0	ok
790	2026-07-31 22:07:31.202177+00	0.35	0	1906	1283	0	20	58	125	11	1	0	ok
791	2026-07-31 22:08:31.202454+00	0.14	0	1906	1281	0	20	58	126	11	1	0	ok
792	2026-07-31 22:09:31.20266+00	0.08	0	1906	1273	0	20	58	126	11	1	0	ok
793	2026-07-31 22:10:31.204258+00	0.06	0	1906	1276	0	20	58	126	11	1	0	ok
794	2026-07-31 22:11:31.205052+00	0.02	0	1906	1283	0	20	58	126	11	1	0	ok
795	2026-07-31 22:12:31.206939+00	0.05	0	1906	1273	0	20	58	126	11	1	0	ok
796	2026-07-31 22:13:31.205175+00	0.02	0	1906	1278	0	20	58	125	11	1	0	ok
797	2026-07-31 22:14:12.156386+00	0.01	0	1906	1336	0	20	58	99	12	1	0	ok
798	2026-07-31 22:15:12.156326+00	0	0	1906	1317	0	20	58	85	16	1	0	ok
799	2026-07-31 22:16:12.157179+00	0.47	0	1906	1312	0	20	58	87	17	1	0	ok
800	2026-07-31 22:17:12.154876+00	0.17	0	1906	1313	0	20	58	88	16	1	0	ok
801	2026-07-31 22:18:12.161423+00	0.06	0	1906	1304	0	20	58	92	17	1	0	ok
802	2026-07-31 22:19:12.161941+00	0.02	0	1906	1302	0	20	58	92	17	1	0	ok
803	2026-07-31 22:20:12.164361+00	0.01	0	1906	1301	0	20	58	93	19	1	0	ok
804	2026-07-31 22:21:12.163752+00	0.08	0	1906	1297	0	20	58	94	18	1	0	ok
805	2026-07-31 22:22:12.165563+00	0.37	0	1906	1301	0	20	58	96	19	1	0	ok
806	2026-07-31 22:23:12.166383+00	0.13	0	1906	1293	0	20	58	98	17	1	0	ok
807	2026-07-31 22:24:12.170761+00	0.05	0	1906	1300	0	20	58	98	19	1	0	ok
808	2026-07-31 22:25:12.166789+00	0.22	0	1906	1294	0	20	58	98	18	1	0	ok
809	2026-07-31 22:26:12.167227+00	0.08	0	1906	1303	0	20	58	99	19	1	0	ok
810	2026-07-31 22:27:12.168879+00	0.03	0	1906	1296	0	20	58	101	18	1	0	ok
811	2026-07-31 22:28:12.169342+00	0.01	0	1906	1296	0	20	58	100	19	1	0	ok
812	2026-07-31 22:29:12.169996+00	0.61	0	1906	1306	0	20	58	93	18	1	0	ok
813	2026-07-31 22:30:12.171807+00	0.22	0	1906	1295	0	20	58	95	19	1	0	ok
814	2026-07-31 22:31:12.172398+00	0.08	0	1906	1293	0	20	58	95	18	1	0	ok
815	2026-07-31 22:32:12.173643+00	0.06	0	1906	1301	0	20	58	96	19	1	0	ok
816	2026-07-31 22:33:12.173718+00	0.13	0	1906	1298	0	20	58	97	18	1	0	ok
817	2026-07-31 22:34:12.173831+00	0.2	0	1906	1283	0	20	58	98	19	1	0	ok
818	2026-07-31 22:35:12.17416+00	0.34	0	1906	1279	0	20	58	98	18	1	0	ok
819	2026-07-31 22:36:12.174369+00	0.12	0	1906	1287	0	20	58	99	19	1	0	ok
820	2026-07-31 22:37:12.17455+00	0.45	0	1906	1270	0	20	58	100	18	1	0	ok
821	2026-07-31 22:38:12.177129+00	0.16	0	1906	1269	0	20	58	101	19	1	0	ok
822	2026-07-31 22:39:12.178989+00	0.06	0	1906	1277	0	20	58	101	18	1	0	ok
823	2026-07-31 22:40:12.178687+00	0.76	0	1906	1278	0	20	58	101	19	1	0	ok
824	2026-07-31 22:41:12.189367+00	0.62	0	1906	1280	0	20	58	102	18	1	0	ok
825	2026-07-31 22:42:12.18031+00	0.56	0	1906	1285	0	20	58	102	16	1	0	ok
826	2026-07-31 22:43:12.180982+00	0.51	0	1906	1279	0	20	58	102	17	1	0	ok
827	2026-07-31 22:44:12.180059+00	0.53	0	1906	1283	0	20	58	103	14	1	0	ok
828	2026-07-31 22:45:12.182167+00	0.19	0	1906	1281	0	20	58	101	18	1	0	ok
829	2026-07-31 22:46:12.182897+00	0.34	0	1906	1283	0	20	58	102	18	1	0	ok
830	2026-07-31 22:47:12.182189+00	0.53	0	1906	1284	0	20	58	102	17	1	0	ok
831	2026-07-31 22:48:12.181487+00	0.23	0	1906	1282	0	20	58	102	18	1	0	ok
832	2026-07-31 22:49:12.182447+00	0.15	0	1906	1277	0	20	58	102	18	1	0	ok
833	2026-07-31 22:50:12.180642+00	0.5	0	1906	1281	0	20	58	102	19	1	0	ok
834	2026-07-31 22:51:12.182911+00	0.32	0	1906	1287	0	20	58	102	18	1	0	ok
835	2026-07-31 22:52:12.181873+00	0.39	0	1906	1284	0	20	58	102	17	1	0	ok
836	2026-07-31 22:53:12.182056+00	0.53	0	1906	1284	0	20	58	103	18	1	0	ok
837	2026-07-31 22:54:12.181395+00	0.19	0	1906	1284	0	20	58	102	18	1	0	ok
838	2026-07-31 22:55:12.180895+00	0.14	0	1906	1277	0	20	58	102	18	1	0	ok
839	2026-07-31 22:56:12.181664+00	0.43	0	1906	1268	0	20	58	103	19	1	0	ok
840	2026-07-31 22:57:12.180955+00	0.16	0	1906	1279	0	20	58	103	17	1	0	ok
841	2026-07-31 22:58:12.182861+00	0.46	0	1906	1284	0	20	58	102	18	1	0	ok
842	2026-07-31 22:59:12.183662+00	0.17	0	1906	1273	0	20	58	102	17	1	0	ok
843	2026-07-31 23:00:12.182043+00	0.06	0	1906	1269	0	20	58	102	17	1	0	ok
844	2026-07-31 23:01:12.183288+00	0.22	0	1906	1270	0	20	58	103	18	1	0	ok
845	2026-07-31 23:02:12.183339+00	0.08	0	1906	1268	0	20	58	103	19	1	0	ok
846	2026-07-31 23:03:12.18267+00	0.03	0	1906	1272	0	20	58	102	17	1	0	ok
847	2026-07-31 23:04:12.183631+00	0.41	0	1906	1273	0	20	58	102	19	1	0	ok
848	2026-07-31 23:05:12.184297+00	0.76	0	1906	1269	0	20	58	103	17	1	0	ok
849	2026-07-31 23:06:12.184162+00	0.35	0	1906	1273	0	20	58	102	19	1	0	ok
850	2026-07-31 23:07:12.183814+00	0.53	0	1906	1275	0	20	58	102	17	1	0	ok
851	2026-07-31 23:08:12.185276+00	0.33	0	1906	1275	0	20	58	102	19	1	0	ok
852	2026-07-31 23:09:12.184115+00	0.23	0	1906	1286	0	20	58	103	17	1	0	ok
853	2026-07-31 23:10:12.185706+00	0.56	0	1906	1273	0	20	58	103	19	1	0	ok
854	2026-07-31 23:11:12.185247+00	0.27	0	1906	1274	0	20	58	102	18	1	0	ok
855	2026-07-31 23:12:12.186293+00	0.44	0	1906	1274	0	20	58	103	19	1	0	ok
856	2026-07-31 23:13:12.185913+00	0.5	0	1906	1285	0	20	58	103	18	1	0	ok
857	2026-07-31 23:14:12.185146+00	0.25	0	1906	1280	0	20	58	103	19	1	0	ok
858	2026-07-31 23:15:12.184681+00	0.43	0	1906	1281	0	20	58	103	18	1	0	ok
859	2026-07-31 23:16:12.185465+00	0.29	0	1906	1282	0	20	58	102	19	1	0	ok
860	2026-07-31 23:17:12.187201+00	0.24	0.5	1906	1282	0	20	58	102	18	1	0	ok
861	2026-07-31 23:18:12.186756+00	0.43	0	1906	1289	0	20	58	103	17	1	0	ok
862	2026-07-31 23:19:12.187296+00	0.22	0	1906	1279	0	20	58	102	18	1	0	ok
863	2026-07-31 23:20:12.187469+00	0.15	0	1906	1281	0	20	58	102	19	1	0	ok
864	2026-07-31 23:21:12.186426+00	0.53	0	1906	1278	0	20	58	103	18	1	0	ok
865	2026-07-31 23:22:12.188298+00	0.53	0.5	1906	1283	0	20	58	102	19	1	0	ok
866	2026-07-31 23:23:12.187107+00	0.53	0	1906	1283	0	20	58	103	18	1	0	ok
867	2026-07-31 23:24:12.187464+00	0.53	0	1906	1277	0	20	58	103	19	1	0	ok
868	2026-07-31 23:25:12.186693+00	0.4	0	1906	1275	0	20	58	103	18	1	0	ok
869	2026-07-31 23:26:12.186868+00	0.41	0	1906	1279	0	20	58	103	19	1	0	ok
870	2026-07-31 23:27:12.187112+00	0.49	0	1906	1284	0	20	58	103	18	1	0	ok
871	2026-07-31 23:28:12.188967+00	0.59	0	1906	1275	0	20	58	104	19	1	0	ok
872	2026-07-31 23:29:12.187961+00	0.55	0	1906	1278	0	20	58	103	18	1	0	ok
873	2026-07-31 23:30:12.187273+00	0.73	0	1906	1278	0	20	58	103	19	1	0	ok
874	2026-07-31 23:31:12.187453+00	0.73	0	1906	1275	0	20	58	104	18	1	0	ok
875	2026-07-31 23:32:12.187304+00	0.67	0	1906	1278	0	20	58	103	19	1	0	ok
876	2026-07-31 23:33:12.186422+00	0.61	0	1906	1279	0	20	58	103	18	1	0	ok
877	2026-07-31 23:34:12.219246+00	0.59	0	1906	1273	0	20	58	103	19	1	0	ok
878	2026-07-31 23:35:12.188236+00	0.78	0	1906	1279	0	20	58	103	18	1	0	ok
879	2026-07-31 23:36:12.187779+00	0.65	0	1906	1282	0	20	58	103	19	1	0	ok
880	2026-07-31 23:37:12.188902+00	0.31	0	1906	1272	0	20	58	103	18	1	0	ok
881	2026-07-31 23:38:12.188597+00	0.33	0	1906	1273	0	20	58	103	19	1	0	ok
882	2026-07-31 23:39:12.189932+00	0.49	0	1906	1272	0	20	58	103	18	1	0	ok
883	2026-07-31 23:40:12.191567+00	0.25	0	1906	1270	0	20	58	103	19	1	0	ok
884	2026-07-31 23:41:12.189958+00	0.24	0	1906	1282	0	20	58	103	18	1	0	ok
885	2026-07-31 23:42:12.190691+00	0.45	0	1906	1275	0	20	58	103	19	1	0	ok
886	2026-07-31 23:43:12.19087+00	0.24	0	1906	1276	0	20	58	103	18	1	0	ok
887	2026-07-31 23:44:12.191048+00	0.16	0	1906	1278	0	20	58	103	19	1	0	ok
888	2026-07-31 23:45:12.192218+00	0.2	0	1906	1278	0	20	58	101	18	1	0	ok
889	2026-07-31 23:46:12.190994+00	0.15	0	1906	1279	0	20	58	102	19	1	0	ok
890	2026-07-31 23:47:12.190159+00	0.13	0	1906	1281	0	20	58	102	16	1	0	ok
891	2026-07-31 23:48:12.191045+00	0.12	0	1906	1278	0	20	58	103	19	1	0	ok
892	2026-07-31 23:49:12.193332+00	0.56	0	1906	1281	0	20	58	103	18	1	0	ok
893	2026-07-31 23:50:12.193447+00	0.33	0	1906	1280	0	20	58	103	19	1	0	ok
894	2026-07-31 23:51:12.191624+00	0.2	0	1906	1267	0	20	58	103	18	1	0	ok
895	2026-07-31 23:52:12.193881+00	0.14	0	1906	1282	0	20	58	103	17	1	0	ok
896	2026-07-31 23:53:12.194034+00	0.42	0	1906	1276	0	20	58	103	18	1	0	ok
897	2026-07-31 23:54:12.194226+00	0.37	0.5	1906	1277	0	20	58	103	19	1	0	ok
898	2026-07-31 23:55:12.196232+00	0.2	0	1906	1277	0	20	58	103	18	1	0	ok
899	2026-07-31 23:56:12.198141+00	0.22	0	1906	1277	0	20	58	103	19	1	0	ok
900	2026-07-31 23:57:12.196068+00	0.3	0	1906	1277	0	20	58	103	18	1	0	ok
901	2026-07-31 23:58:12.19688+00	0.26	0	1906	1274	0	20	58	103	19	1	0	ok
902	2026-07-31 23:59:12.199618+00	0.17	0	1906	1277	0	20	58	103	18	1	0	ok
903	2026-08-01 00:00:12.200459+00	0.06	0	1906	1261	0	20	57	103	19	1	0	ok
904	2026-08-01 00:01:12.199924+00	0.24	0	1906	1262	0	20	57	103	18	1	0	ok
905	2026-08-01 00:02:12.202358+00	0.16	0	1906	1257	0	20	57	103	19	1	0	ok
906	2026-08-01 00:03:12.20085+00	0.13	0	1906	1259	0	20	57	103	18	1	0	ok
907	2026-08-01 00:04:12.200864+00	0.19	0	1906	1261	0	20	57	103	17	1	0	ok
908	2026-08-01 00:05:12.200996+00	0.14	0	1906	1262	0	20	57	103	18	1	0	ok
909	2026-08-01 00:06:12.201861+00	0.49	0	1906	1260	0	20	57	103	19	1	0	ok
910	2026-08-01 00:07:12.202797+00	0.25	0	1906	1265	0	20	57	104	18	1	0	ok
911	2026-08-01 00:08:12.204685+00	0.17	0	1906	1261	0	20	57	104	19	1	0	ok
912	2026-08-01 00:09:12.20423+00	0.13	0	1906	1262	0	20	57	103	18	1	0	ok
913	2026-08-01 00:10:12.204715+00	0.64	0	1906	1264	0	20	57	104	17	1	0	ok
914	2026-08-01 00:11:12.205088+00	0.38	0	1906	1271	0	20	57	104	18	1	0	ok
915	2026-08-01 00:12:12.205244+00	0.14	0	1906	1270	0	20	57	103	16	1	0	ok
916	2026-08-01 00:13:12.206106+00	0.05	0	1906	1265	0	20	57	103	18	1	0	ok
917	2026-08-01 00:14:12.207909+00	0.16	0	1906	1265	0	20	57	104	18	1	0	ok
918	2026-08-01 00:15:12.209894+00	0.13	0	1906	1264	0	20	57	104	16	1	0	ok
919	2026-08-01 00:16:12.209222+00	0.12	0.5	1906	1257	0	20	57	104	19	1	0	ok
920	2026-08-01 00:17:12.208815+00	0.12	0	1906	1258	0	20	57	104	17	1	0	ok
921	2026-08-01 00:18:12.210446+00	0.11	0.5	1906	1272	0	20	57	104	13	1	0	ok
922	2026-08-01 00:19:12.211448+00	0.16	0.5	1906	1266	0	20	57	104	13	1	0	ok
923	2026-08-01 00:20:12.211654+00	0.35	0	1906	1269	0	20	57	104	14	1	0	ok
924	2026-08-01 00:21:12.210598+00	0.2	0	1906	1270	0	20	57	104	13	1	0	ok
925	2026-08-01 00:22:12.211829+00	0.15	0	1906	1269	0	20	57	105	13	1	0	ok
926	2026-08-01 00:23:12.21307+00	0.13	0	1906	1273	0	20	57	105	12	1	0	ok
927	2026-08-01 00:24:12.212163+00	0.19	0	1906	1274	0	20	57	104	13	1	0	ok
928	2026-08-01 00:25:12.213384+00	0.29	0	1906	1270	0	20	57	104	12	1	0	ok
929	2026-08-01 00:26:12.212885+00	0.25	0	1906	1274	0	20	57	104	12	1	0	ok
930	2026-08-01 00:27:12.212402+00	0.16	0	1906	1272	0	20	57	104	13	1	0	ok
931	2026-08-01 00:28:12.213396+00	0.13	0	1906	1265	0	20	57	105	12	1	0	ok
932	2026-08-01 00:29:12.212585+00	0.12	0	1906	1270	0	20	57	104	13	1	0	ok
933	2026-08-01 00:30:12.212586+00	0.34	0	1906	1269	0	20	57	104	14	1	0	ok
934	2026-08-01 00:31:12.213415+00	0.2	0	1906	1263	0	20	57	104	17	1	0	ok
935	2026-08-01 00:32:12.21379+00	0.14	0	1906	1263	0	20	57	104	15	1	0	ok
936	2026-08-01 00:33:12.213517+00	0.13	0	1906	1269	0	20	57	104	15	1	0	ok
937	2026-08-01 00:34:12.216074+00	0.12	0.5	1906	1261	0	20	57	104	16	1	0	ok
938	2026-08-01 00:35:12.215073+00	0.12	0	1906	1267	0	20	57	104	16	1	0	ok
939	2026-08-01 00:36:12.214567+00	0.11	0	1906	1264	0	20	57	104	16	1	0	ok
940	2026-08-01 00:37:12.214638+00	0.11	0	1906	1274	0	20	57	104	16	1	0	ok
941	2026-08-01 00:38:12.21447+00	0.11	0.5	1906	1264	0	20	57	104	16	1	0	ok
942	2026-08-01 00:39:12.215816+00	0.11	0	1906	1266	0	20	57	104	15	1	0	ok
943	2026-08-01 00:40:12.218478+00	0.11	0	1906	1270	0	20	57	104	16	1	0	ok
944	2026-08-01 00:41:12.215902+00	0.11	0	1906	1277	0	20	57	104	13	1	0	ok
945	2026-08-01 00:42:12.237897+00	0.11	0	1906	1261	0	20	57	104	13	1	0	ok
946	2026-08-01 00:43:12.217657+00	0.11	0	1906	1277	0	20	57	96	13	1	0	ok
947	2026-08-01 00:44:12.216916+00	0.11	0	1906	1274	0	20	57	97	14	1	0	ok
948	2026-08-01 00:45:12.216165+00	0.15	0	1906	1273	0	20	57	98	13	1	0	ok
949	2026-08-01 00:46:12.219664+00	0.05	0	1906	1262	0	20	57	99	17	1	0	ok
950	2026-08-01 00:47:12.221614+00	0.24	0	1906	1266	0	20	57	99	17	1	0	ok
951	2026-08-01 00:48:12.221125+00	0.16	0	1906	1263	0	20	57	100	17	1	0	ok
952	2026-08-01 00:49:12.219924+00	0.19	0	1906	1262	0	20	57	100	17	1	0	ok
953	2026-08-01 00:50:12.221633+00	0.14	0	1906	1264	0	20	57	102	17	1	0	ok
954	2026-08-01 00:51:12.220601+00	0.12	0	1906	1268	0	20	57	102	17	1	0	ok
955	2026-08-01 00:52:12.22216+00	0.17	0.5	1906	1267	0	20	57	103	17	1	0	ok
956	2026-08-01 00:53:12.221419+00	0.14	0	1906	1266	0	20	57	103	17	1	0	ok
957	2026-08-01 00:54:12.222228+00	0.12	0	1906	1268	0	20	57	103	17	1	0	ok
958	2026-08-01 00:55:12.222321+00	0.12	0	1906	1256	0	20	57	103	17	1	0	ok
959	2026-08-01 00:56:12.223484+00	0.19	0	1906	1261	0	20	57	103	16	1	0	ok
960	2026-08-01 00:57:12.222449+00	0.14	0	1906	1263	0	20	57	104	15	1	0	ok
961	2026-08-01 00:58:12.22505+00	0.2	0.5	1906	1258	0	20	57	104	16	1	0	ok
962	2026-08-01 00:59:12.223252+00	0.14	0	1906	1257	0	20	57	103	17	1	0	ok
963	2026-08-01 01:00:12.223322+00	0.13	0	1906	1265	0	20	57	103	17	1	0	ok
964	2026-08-01 01:01:12.223632+00	0.12	0	1906	1261	0	20	57	104	17	1	0	ok
965	2026-08-01 01:02:12.226289+00	0.12	0	1906	1257	0	20	57	103	19	1	0	ok
966	2026-08-01 01:03:12.225482+00	0.11	0	1906	1263	0	20	57	103	18	1	0	ok
967	2026-08-01 01:04:12.226354+00	0.11	0	1906	1256	0	20	57	104	19	1	0	ok
968	2026-08-01 01:05:12.225023+00	0.11	0	1906	1262	0	20	57	104	18	1	0	ok
969	2026-08-01 01:06:12.22452+00	0.11	0	1906	1262	0	20	57	104	19	1	0	ok
970	2026-08-01 01:07:12.22447+00	0.11	0	1906	1258	0	20	57	104	18	1	0	ok
971	2026-08-01 01:08:12.225344+00	0.11	0	1906	1259	0	20	57	105	19	1	0	ok
972	2026-08-01 01:09:12.223769+00	0.11	0	1906	1265	0	20	57	104	18	1	0	ok
973	2026-08-01 01:10:12.224968+00	0.11	0	1906	1258	0	20	57	105	19	1	0	ok
974	2026-08-01 01:11:12.226422+00	0.11	0	1906	1263	0	20	57	105	18	1	0	ok
975	2026-08-01 01:12:12.231125+00	0.11	0	1906	1253	0	20	57	104	19	1	0	ok
976	2026-08-01 01:13:12.228091+00	0.11	0	1906	1264	0	20	57	104	18	1	0	ok
977	2026-08-01 01:14:12.227965+00	0.41	0	1906	1263	0	20	57	105	19	1	0	ok
978	2026-08-01 01:15:12.226814+00	0.22	0	1906	1262	0	20	57	105	16	1	0	ok
979	2026-08-01 01:16:12.230313+00	0.08	0	1906	1258	0	20	57	106	19	1	0	ok
980	2026-08-01 01:17:12.229446+00	0.1	0	1906	1254	0	20	57	105	18	1	0	ok
981	2026-08-01 01:18:12.230332+00	0.11	0.5	1906	1258	0	20	57	105	19	1	0	ok
982	2026-08-01 01:19:12.230845+00	0.04	0	1906	1263	0	20	57	105	12	1	0	ok
983	2026-08-01 01:20:12.231562+00	0.09	0	1906	1264	0	20	57	105	19	1	0	ok
984	2026-08-01 01:21:12.231886+00	0.1	0	1906	1258	0	20	57	105	15	1	0	ok
985	2026-08-01 01:22:12.234459+00	0.11	0	1906	1258	0	20	57	106	19	1	0	ok
986	2026-08-01 01:23:12.232929+00	0.19	0	1906	1258	0	20	57	105	18	1	0	ok
987	2026-08-01 01:24:12.236563+00	0.14	0	1906	1255	0	20	57	105	19	1	0	ok
988	2026-08-01 01:25:12.235792+00	0.12	0	1906	1254	0	20	57	105	18	1	0	ok
989	2026-08-01 01:26:12.236227+00	0.12	0	1906	1256	0	20	57	105	19	1	0	ok
990	2026-08-01 01:27:12.238529+00	0.16	0	1906	1256	0	20	57	105	18	1	0	ok
991	2026-08-01 01:28:12.241701+00	0.13	0	1906	1255	0	20	57	105	19	1	0	ok
992	2026-08-01 01:29:12.240439+00	0.05	0	1906	1254	0	20	57	105	18	1	0	ok
993	2026-08-01 01:30:12.243261+00	0.16	0	1906	1252	0	20	57	105	19	1	0	ok
994	2026-08-01 01:31:12.243563+00	0.06	0.5	1906	1255	0	20	57	105	18	1	0	ok
995	2026-08-01 01:32:12.243099+00	0.02	0.5	1906	1262	0	20	57	105	15	1	0	ok
996	2026-08-01 01:33:12.242922+00	0	0	1906	1260	0	20	57	105	16	1	0	ok
997	2026-08-01 01:34:12.244055+00	0.07	0	1906	1260	0	20	57	105	16	1	0	ok
998	2026-08-01 01:35:12.244915+00	0.02	0	1906	1265	0	20	57	105	16	1	0	ok
999	2026-08-01 01:36:12.244237+00	0.08	0	1906	1254	0	20	56	106	21	1	0	ok
1000	2026-08-01 01:37:12.2435+00	0.03	0	1906	1253	0	20	56	105	21	1	0	ok
1001	2026-08-01 01:38:12.243445+00	0.08	0	1906	1267	0	20	56	105	16	1	0	ok
1002	2026-08-01 01:39:12.245369+00	0.1	0	1906	1263	0	20	56	105	15	1	0	ok
1003	2026-08-01 01:40:12.245665+00	0.2	0	1906	1263	0	20	56	105	18	1	0	ok
1004	2026-08-01 01:41:12.247059+00	0.2	0	1906	1251	0	20	56	105	18	1	0	ok
1005	2026-08-01 01:42:12.246045+00	0.07	0	1906	1256	0	20	56	106	16	1	0	ok
1006	2026-08-01 01:43:12.247241+00	0.02	0	1906	1264	0	20	56	105	18	1	0	ok
1007	2026-08-01 01:44:12.248272+00	0.01	0	1906	1254	0	20	56	106	15	1	0	ok
1008	2026-08-01 01:45:12.246103+00	0.07	0	1906	1250	0	20	56	105	18	1	0	ok
1009	2026-08-01 01:46:12.24591+00	0.03	0	1906	1259	0	20	56	105	18	1	0	ok
1010	2026-08-01 01:47:12.246382+00	0.01	0	1906	1259	0	20	56	106	17	1	0	ok
1011	2026-08-01 01:48:12.246008+00	0.07	0	1906	1249	0	20	56	105	18	1	0	ok
1012	2026-08-01 01:49:12.24645+00	0.09	0	1906	1250	0	20	56	105	14	1	0	ok
1013	2026-08-01 01:50:12.247681+00	0.11	0	1906	1263	0	20	56	107	17	1	0	ok
1014	2026-08-01 01:51:12.2469+00	0.04	0	1906	1261	0	20	56	105	14	1	0	ok
1015	2026-08-01 01:52:12.246514+00	0.01	0	1906	1253	0	20	56	105	17	1	0	ok
1016	2026-08-01 01:53:12.247557+00	0	0	1906	1257	0	20	56	106	18	1	0	ok
1017	2026-08-01 01:54:12.247041+00	0.07	0	1906	1253	0	20	56	106	17	1	0	ok
1018	2026-08-01 01:55:12.24737+00	0.1	0	1906	1251	0	20	56	106	18	1	0	ok
1019	2026-08-01 01:56:12.249387+00	0.11	0	1906	1250	0	20	56	106	19	1	0	ok
1020	2026-08-01 01:57:12.248283+00	0.21	0	1906	1231	0	20	56	106	16	1	0	ok
1021	2026-08-01 01:58:12.249806+00	0.16	0	1906	1225	0	20	56	106	19	1	0	ok
1022	2026-08-01 01:59:12.250497+00	0.06	0	1906	1233	0	20	56	105	16	1	0	ok
1023	2026-08-01 02:00:12.249764+00	0.09	0	1906	1222	0	20	56	105	19	1	0	ok
1024	2026-08-01 02:01:12.248885+00	0.03	0	1906	1221	0	20	57	106	18	1	0	ok
1025	2026-08-01 02:02:12.250348+00	0.01	0	1906	1235	0	20	57	105	19	1	0	ok
1026	2026-08-01 02:03:12.250186+00	0	0	1906	1222	0	20	57	106	18	1	0	ok
1027	2026-08-01 02:04:12.250089+00	0	0	1906	1233	0	20	57	106	19	1	0	ok
1028	2026-08-01 02:05:12.250173+00	0.07	0	1906	1220	0	20	57	106	16	1	0	ok
1029	2026-08-01 02:06:12.253158+00	0.02	0	1906	1223	0	20	57	105	18	1	0	ok
1030	2026-08-01 02:07:12.252107+00	0.01	0	1906	1222	0	20	57	106	19	1	0	ok
1031	2026-08-01 02:08:12.253762+00	0	0	1906	1221	0	20	57	105	20	1	0	ok
1032	2026-08-01 02:09:12.259292+00	0.07	0	1906	1234	0	20	57	106	17	1	0	ok
1033	2026-08-01 02:10:12.255803+00	0.02	0.5	1906	1227	0	20	57	106	19	1	0	ok
1034	2026-08-01 02:11:12.257202+00	0.01	0	1906	1228	0	20	57	106	18	1	0	ok
1035	2026-08-01 02:12:12.258272+00	0	0	1906	1223	0	20	57	105	19	1	0	ok
1036	2026-08-01 02:13:12.257067+00	0	0	1906	1231	0	20	57	106	18	1	0	ok
1037	2026-08-01 02:14:12.257985+00	0.07	0.5	1906	1235	0	20	57	106	18	1	0	ok
1038	2026-08-01 02:15:12.257412+00	0.02	0	1906	1246	0	20	57	106	18	1	0	ok
1039	2026-08-01 02:16:12.265102+00	0.01	0	1906	1232	0	20	57	106	19	1	0	ok
1040	2026-08-01 02:17:12.259712+00	0	0	1906	1229	0	20	57	106	18	1	0	ok
1041	2026-08-01 02:18:12.260989+00	0.07	0	1906	1234	0	20	57	106	19	1	0	ok
1042	2026-08-01 02:19:12.262141+00	0.02	0	1906	1234	0	20	57	106	18	1	0	ok
1043	2026-08-01 02:20:12.262495+00	0.01	0	1906	1236	0	20	57	106	18	1	0	ok
1044	2026-08-01 02:21:12.260578+00	0	0	1906	1230	0	20	57	106	16	1	0	ok
1045	2026-08-01 02:22:12.262532+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1046	2026-08-01 02:23:12.264887+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1047	2026-08-01 02:24:12.266507+00	0	0	1906	1231	0	20	57	106	20	1	0	ok
1048	2026-08-01 02:25:12.264102+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1049	2026-08-01 02:26:12.265036+00	0	0	1906	1234	0	20	57	106	17	1	0	ok
1050	2026-08-01 02:27:12.266447+00	0	0.5	1906	1236	0	20	57	106	18	1	0	ok
1051	2026-08-01 02:28:12.266872+00	0	0	1906	1231	0	20	57	106	19	1	0	ok
1052	2026-08-01 02:29:12.267163+00	0	0	1906	1233	0	20	57	106	18	1	0	ok
1053	2026-08-01 02:30:12.270461+00	0.07	0	1906	1233	0	20	57	106	19	1	0	ok
1054	2026-08-01 02:31:12.269238+00	0.02	0	1906	1222	0	20	57	106	18	1	0	ok
1055	2026-08-01 02:32:12.268246+00	0.01	0	1906	1235	0	20	57	107	19	1	0	ok
1056	2026-08-01 02:33:12.270433+00	0	0	1906	1231	0	20	57	106	18	1	0	ok
1057	2026-08-01 02:34:12.272126+00	0	0	1906	1231	0	20	57	106	19	1	0	ok
1058	2026-08-01 02:35:12.27152+00	0	0	1906	1235	0	20	57	106	18	1	0	ok
1059	2026-08-01 02:36:12.270508+00	0	0	1906	1220	0	20	57	107	19	1	0	ok
1060	2026-08-01 02:37:12.271551+00	0	0	1906	1221	0	20	57	107	18	1	0	ok
1061	2026-08-01 02:38:12.273606+00	0	0	1906	1222	0	20	57	106	19	1	0	ok
1062	2026-08-01 02:39:12.27137+00	0	0	1906	1227	0	20	57	106	16	1	0	ok
1063	2026-08-01 02:40:12.275623+00	0	0	1906	1219	0	20	57	106	18	1	0	ok
1064	2026-08-01 02:41:12.274158+00	0	0	1906	1224	0	20	57	106	19	1	0	ok
1065	2026-08-01 02:42:12.273954+00	0	0	1906	1229	0	20	57	106	20	1	0	ok
1066	2026-08-01 02:43:12.274001+00	0	0	1906	1228	0	20	57	106	19	1	0	ok
1067	2026-08-01 02:44:12.274772+00	0	0	1906	1207	0	20	57	106	20	1	0	ok
1068	2026-08-01 02:45:12.276671+00	0	0	1906	1226	0	20	57	106	19	1	0	ok
1069	2026-08-01 02:46:12.273729+00	0	0	1906	1230	0	20	57	107	19	1	0	ok
1070	2026-08-01 02:47:12.274523+00	0	0	1906	1224	0	20	57	106	18	1	0	ok
1071	2026-08-01 02:48:12.27503+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1072	2026-08-01 02:49:12.275402+00	0	0	1906	1231	0	20	57	106	17	1	0	ok
1073	2026-08-01 02:50:12.278247+00	0.06	0	1906	1248	0	20	57	107	19	1	0	ok
1074	2026-08-01 02:51:12.275327+00	0.02	0	1906	1235	0	20	57	106	18	1	0	ok
1075	2026-08-01 02:52:12.278726+00	0.01	0	1906	1229	0	20	57	107	19	1	0	ok
1076	2026-08-01 02:53:12.279761+00	0	0	1906	1235	0	20	57	107	18	1	0	ok
1077	2026-08-01 02:54:12.281078+00	0	0	1906	1233	0	20	57	107	19	1	0	ok
1078	2026-08-01 02:55:12.282103+00	0	0	1906	1227	0	20	57	106	18	1	0	ok
1079	2026-08-01 02:56:12.282715+00	0	0	1906	1237	0	20	57	108	12	1	0	ok
1080	2026-08-01 02:57:12.281774+00	0	0	1906	1245	0	20	57	106	12	1	0	ok
1081	2026-08-01 02:58:12.283482+00	0	0	1906	1238	0	20	57	107	12	1	0	ok
1082	2026-08-01 02:59:12.284712+00	0	0	1906	1246	0	20	57	106	10	1	0	ok
1083	2026-08-01 03:00:12.283809+00	0.07	0	1906	1240	0	20	57	107	13	1	0	ok
1084	2026-08-01 03:01:12.282982+00	0.02	0	1906	1244	0	20	57	107	13	1	0	ok
1085	2026-08-01 03:02:12.283644+00	0.01	0	1906	1233	0	20	57	107	16	1	0	ok
1086	2026-08-01 03:03:12.283284+00	0	0	1906	1245	0	20	57	107	15	1	0	ok
1087	2026-08-01 03:04:12.288143+00	0	0.5	1906	1223	0	20	57	107	17	1	0	ok
1088	2026-08-01 03:05:12.287159+00	0	0	1906	1238	0	20	57	107	18	1	0	ok
1089	2026-08-01 03:06:12.288936+00	0	0	1906	1236	0	20	57	106	18	1	0	ok
1090	2026-08-01 03:07:12.287895+00	0	0	1906	1242	0	20	57	107	15	1	0	ok
1091	2026-08-01 03:08:12.288624+00	0	0	1906	1234	0	20	57	106	18	1	0	ok
1092	2026-08-01 03:09:12.287676+00	0	0.5	1906	1255	0	20	57	107	18	1	0	ok
1093	2026-08-01 03:10:12.289954+00	0	0	1906	1245	0	20	57	107	19	1	0	ok
1094	2026-08-01 03:11:12.291132+00	0	0	1906	1249	0	20	57	107	17	1	0	ok
1095	2026-08-01 03:12:12.289783+00	0.04	0	1906	1244	0	20	57	107	19	1	0	ok
1096	2026-08-01 03:13:12.289059+00	0.01	0	1906	1253	0	20	57	107	16	1	0	ok
1097	2026-08-01 03:14:12.290737+00	0	0	1906	1244	0	20	57	107	19	1	0	ok
1098	2026-08-01 03:15:12.290866+00	0	0	1906	1247	0	20	57	107	18	1	0	ok
1099	2026-08-01 03:16:12.289942+00	0	0	1906	1253	0	20	57	107	19	1	0	ok
1100	2026-08-01 03:17:12.289539+00	0	0	1906	1250	0	20	57	107	18	1	0	ok
1101	2026-08-01 03:18:12.292412+00	0	0	1906	1253	0	20	57	107	18	1	0	ok
1102	2026-08-01 03:19:12.293109+00	0	0	1906	1257	0	20	57	107	16	1	0	ok
1103	2026-08-01 03:20:12.292144+00	0	0	1906	1256	0	20	57	107	16	1	0	ok
1104	2026-08-01 03:21:12.290699+00	0	0	1906	1246	0	20	57	107	16	1	0	ok
1105	2026-08-01 03:22:12.29099+00	0	0	1906	1251	0	20	57	107	15	1	0	ok
1106	2026-08-01 03:23:12.291152+00	0	0	1906	1256	0	20	57	107	14	1	0	ok
1107	2026-08-01 03:24:12.291382+00	0	0	1906	1245	0	20	57	107	17	1	0	ok
1108	2026-08-01 03:25:12.292876+00	0	0	1906	1255	0	20	57	107	16	1	0	ok
1109	2026-08-01 03:26:12.293118+00	0	0.5	1906	1243	0	20	57	107	16	1	0	ok
1110	2026-08-01 03:27:12.292202+00	0	0	1906	1249	0	20	57	107	17	1	0	ok
1111	2026-08-01 03:28:12.293123+00	0	0	1906	1246	0	20	57	107	18	1	0	ok
1112	2026-08-01 03:29:12.293275+00	0	0	1906	1246	0	20	57	107	17	1	0	ok
1113	2026-08-01 03:30:12.29427+00	0	0	1906	1246	0	20	57	107	18	1	0	ok
1114	2026-08-01 03:31:12.294447+00	0	0	1906	1266	0	20	57	107	16	1	0	ok
1115	2026-08-01 03:32:12.295201+00	0.06	0	1906	1251	0	20	57	107	17	1	0	ok
1116	2026-08-01 03:33:12.296308+00	0.02	0.5	1906	1253	0	20	57	107	16	1	0	ok
1117	2026-08-01 03:34:12.296402+00	0	0	1906	1252	0	20	57	107	17	1	0	ok
1118	2026-08-01 03:35:12.297612+00	0	0	1906	1247	0	20	57	107	16	1	0	ok
1119	2026-08-01 03:36:12.297782+00	0	0	1906	1253	0	20	57	107	18	1	0	ok
1120	2026-08-01 03:37:12.29723+00	0	0	1906	1250	0	20	57	107	17	1	0	ok
1121	2026-08-01 03:38:12.298641+00	0	0.5	1906	1249	0	20	57	107	18	1	0	ok
1122	2026-08-01 03:39:12.29761+00	0	0	1906	1247	0	20	57	107	17	1	0	ok
1123	2026-08-01 03:40:12.299821+00	0	0	1906	1248	0	20	57	107	19	1	0	ok
1124	2026-08-01 03:41:12.301194+00	0	0	1906	1243	0	20	57	107	18	1	0	ok
1125	2026-08-01 03:42:12.302101+00	0	0	1906	1249	0	20	57	107	19	1	0	ok
1126	2026-08-01 03:43:12.305596+00	0	0	1906	1249	0	20	57	108	18	1	0	ok
1127	2026-08-01 03:44:12.305528+00	0	0	1906	1248	0	20	57	107	19	1	0	ok
1128	2026-08-01 03:45:12.303963+00	0	0	1906	1248	0	20	57	107	17	1	0	ok
1129	2026-08-01 03:46:12.304395+00	0	0.5	1906	1247	0	20	57	106	19	1	0	ok
1130	2026-08-01 03:47:12.30427+00	0	0	1906	1249	0	20	57	106	18	1	0	ok
1131	2026-08-01 03:48:12.304427+00	0	0	1906	1249	0	20	57	106	19	1	0	ok
1132	2026-08-01 03:49:12.303644+00	0	0	1906	1250	0	20	57	106	16	1	0	ok
1133	2026-08-01 03:50:12.306368+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1134	2026-08-01 03:51:12.304828+00	0	0	1906	1246	0	20	57	106	18	1	0	ok
1135	2026-08-01 03:52:12.306237+00	0	0	1906	1247	0	20	57	106	19	1	0	ok
1136	2026-08-01 03:53:12.303855+00	0	0	1906	1244	0	20	57	106	18	1	0	ok
1137	2026-08-01 03:54:12.304956+00	0	0	1906	1245	0	20	57	106	19	1	0	ok
1138	2026-08-01 03:55:12.303228+00	0	0	1906	1252	0	20	57	106	17	1	0	ok
1139	2026-08-01 03:56:12.30478+00	0.1	0	1906	1238	0	20	57	106	18	1	0	ok
1140	2026-08-01 03:57:12.303933+00	0.03	0	1906	1241	0	20	57	106	18	1	0	ok
1141	2026-08-01 03:58:12.305266+00	0.01	0	1906	1249	0	20	57	107	19	1	0	ok
1142	2026-08-01 03:59:12.303915+00	0	0	1906	1240	0	20	57	106	18	1	0	ok
1143	2026-08-01 04:00:12.306762+00	0	0	1906	1245	0	20	57	106	19	1	0	ok
1144	2026-08-01 04:01:12.305439+00	0	0	1906	1251	0	20	57	106	15	1	0	ok
1145	2026-08-01 04:02:12.306641+00	0	0	1906	1254	0	20	57	106	16	1	0	ok
1146	2026-08-01 04:03:12.306725+00	0	0	1906	1241	0	20	57	106	14	1	0	ok
1147	2026-08-01 04:04:12.30787+00	0	0	1906	1249	0	20	57	106	17	1	0	ok
1148	2026-08-01 04:05:12.30777+00	0.68	0	1906	1247	0	20	57	106	18	1	0	ok
1149	2026-08-01 04:06:12.310492+00	0.46	0	1906	1246	0	20	57	106	19	1	0	ok
1150	2026-08-01 04:07:12.310519+00	0.17	0	1906	1247	0	20	57	106	18	1	0	ok
1151	2026-08-01 04:08:12.311479+00	0.06	0	1906	1246	0	20	57	107	18	1	0	ok
1152	2026-08-01 04:09:12.313356+00	0.02	0	1906	1248	0	20	57	106	18	1	0	ok
1153	2026-08-01 04:10:12.314678+00	0.01	0	1906	1248	0	20	57	106	19	1	0	ok
1154	2026-08-01 04:11:12.316135+00	0	0	1906	1252	0	20	57	106	17	1	0	ok
1155	2026-08-01 04:12:12.315117+00	0	0.5	1906	1249	0	20	57	107	19	1	0	ok
1156	2026-08-01 04:13:12.314273+00	0	0	1906	1254	0	20	57	106	18	1	0	ok
1157	2026-08-01 04:14:12.314387+00	0.04	0	1906	1250	0	20	57	106	19	1	0	ok
1158	2026-08-01 04:14:17.212599+00	0.12	0	1906	1291	0	20	57	99	12	1	0	ok
1159	2026-08-01 04:15:17.212508+00	0.25	0	1906	1267	0	20	57	84	16	1	0	ok
1160	2026-08-01 04:16:17.213087+00	0.09	0	1906	1261	0	20	57	87	14	1	0	ok
1161	2026-08-01 04:17:17.212882+00	0.03	0	1906	1266	0	20	57	88	14	1	0	ok
1162	2026-08-01 04:18:17.213265+00	0.06	0	1906	1259	0	20	57	92	18	1	0	ok
1163	2026-08-01 04:19:17.215692+00	0.02	0	1906	1257	0	20	57	92	18	1	0	ok
1164	2026-08-01 04:19:36.51716+00	0.01	0	1906	1296	0	20	57	99	12	1	0	ok
1165	2026-08-01 04:20:36.516243+00	0	0	1906	1275	0	20	57	84	10	1	0	ok
1166	2026-08-01 04:21:36.518073+00	0.08	0	1906	1272	0	20	57	88	10	1	0	ok
1167	2026-08-01 04:22:36.520289+00	0.06	0	1906	1267	0	20	57	90	10	1	0	ok
1168	2026-08-01 04:23:36.520365+00	0.02	0	1906	1251	0	20	57	104	12	1	0	ok
1169	2026-08-01 04:24:36.517662+00	0.04	0	1906	1252	0	20	57	103	12	1	0	ok
1170	2026-08-01 04:25:36.519385+00	0.04	0	1906	1247	0	20	57	104	10	1	0	ok
1171	2026-08-01 04:26:36.520607+00	0.01	0	1906	1240	0	20	57	104	10	1	0	ok
1172	2026-08-01 04:27:36.519377+00	0.58	0	1906	1243	0	20	57	105	10	1	0	ok
1173	2026-08-01 04:28:36.521318+00	0.61	0	1906	1245	0	20	57	106	10	1	0	ok
1174	2026-08-01 04:29:36.521012+00	0.45	0	1906	1256	0	20	57	107	10	1	0	ok
1175	2026-08-01 04:30:36.524814+00	0.43	0	1906	1243	0	20	57	107	10	1	0	ok
1176	2026-08-01 04:31:36.521771+00	0.16	0.51	1906	1254	0	20	57	109	12	1	0	ok
1177	2026-08-01 04:32:36.523598+00	0.19	0	1906	1241	0	20	57	105	10	1	0	ok
1178	2026-08-01 04:33:36.521618+00	0.07	0	1906	1257	0	20	57	106	11	1	0	ok
1179	2026-08-01 04:34:36.524596+00	0.02	0	1906	1256	0	20	57	107	11	1	0	ok
1180	2026-08-01 04:35:36.523242+00	0.01	0	1906	1250	0	20	57	108	12	1	0	ok
1181	2026-08-01 04:36:36.522748+00	0	0	1906	1260	0	20	57	108	11	1	0	ok
1182	2026-08-01 04:37:36.524722+00	0	0	1906	1247	0	20	57	109	12	1	0	ok
1183	2026-08-01 04:38:36.524858+00	0	0	1906	1253	0	20	57	110	9	1	0	ok
1184	2026-08-01 04:39:36.525694+00	0	0	1906	1242	0	20	57	112	12	1	0	ok
1185	2026-08-01 04:40:36.526448+00	0	0	1906	1239	0	20	57	111	10	1	0	ok
1186	2026-08-01 04:41:36.527533+00	0	0	1906	1247	0	20	57	112	13	1	0	ok
1187	2026-08-01 04:42:36.528394+00	0	0	1906	1236	0	20	57	112	13	1	0	ok
1188	2026-08-01 04:43:36.528176+00	0	0	1906	1244	0	20	57	111	14	1	0	ok
1189	2026-08-01 04:44:36.52794+00	0	0	1906	1246	0	20	57	111	12	1	0	ok
1190	2026-08-01 04:45:36.527546+00	0.05	0	1906	1247	0	20	57	111	13	1	0	ok
1191	2026-08-01 04:46:36.535827+00	0.02	0	1906	1240	0	20	57	111	9	1	0	ok
1192	2026-08-01 04:47:36.527927+00	0	0	1906	1250	0	20	57	112	10	1	0	ok
1193	2026-08-01 04:48:36.528321+00	0	0	1906	1253	0	20	57	111	9	1	0	ok
1194	2026-08-01 04:49:36.529136+00	0	0	1906	1251	0	20	57	111	9	1	0	ok
1195	2026-08-01 04:50:36.528172+00	0	0	1906	1254	0	20	57	112	9	1	0	ok
1196	2026-08-01 04:51:36.529238+00	0	0	1906	1241	0	20	57	113	10	1	0	ok
1197	2026-08-01 04:52:36.529601+00	0	0	1906	1244	0	20	57	113	10	1	0	ok
1198	2026-08-01 04:53:36.534241+00	0	0	1906	1236	0	20	57	112	10	1	0	ok
1199	2026-08-01 04:54:36.531615+00	0	0	1906	1243	0	20	57	113	10	1	0	ok
1200	2026-08-01 04:55:36.53179+00	0	0	1906	1235	0	20	57	113	10	1	0	ok
1201	2026-08-01 04:56:36.532318+00	0	0	1906	1240	0	20	57	113	10	1	0	ok
1202	2026-08-01 04:57:36.533505+00	0	0	1906	1245	0	20	57	113	10	1	0	ok
1203	2026-08-01 04:58:36.533142+00	0	0	1906	1245	0	20	57	113	10	1	0	ok
1204	2026-08-01 04:59:36.533745+00	0	0	1906	1234	0	20	57	114	10	1	0	ok
1205	2026-08-01 05:00:36.532843+00	0	0	1906	1244	0	20	57	113	10	1	0	ok
1206	2026-08-01 05:01:36.532877+00	0	0.5	1906	1238	0	20	57	113	10	1	0	ok
1207	2026-08-01 05:02:36.532477+00	0	0	1906	1239	0	20	57	113	10	1	0	ok
1208	2026-08-01 05:03:36.532553+00	0	0	1906	1255	0	20	57	113	10	1	0	ok
1209	2026-08-01 05:04:36.534483+00	0	0	1906	1247	0	20	57	113	10	1	0	ok
1210	2026-08-01 05:05:36.534971+00	0.07	0	1906	1252	0	20	57	113	10	1	0	ok
1211	2026-08-01 05:06:36.535533+00	0.02	0	1906	1250	0	20	57	113	10	1	0	ok
1212	2026-08-01 05:07:36.534537+00	0.27	0	1906	1241	0	20	57	114	10	1	0	ok
1213	2026-08-01 05:08:36.536069+00	0.1	0	1906	1240	0	20	57	113	10	1	0	ok
1214	2026-08-01 05:09:36.536117+00	0.03	0	1906	1237	0	20	57	113	10	1	0	ok
1215	2026-08-01 05:10:36.53718+00	0.01	0	1906	1248	0	20	57	114	10	1	0	ok
1216	2026-08-01 05:11:36.538274+00	0	0	1906	1236	0	20	57	114	10	1	0	ok
1217	2026-08-01 05:12:36.538484+00	0.27	0	1906	1235	0	20	57	114	10	1	0	ok
1218	2026-08-01 05:13:36.540356+00	0.1	0	1906	1239	0	20	57	114	11	1	0	ok
1219	2026-08-01 05:14:36.540171+00	0.03	0	1906	1228	0	20	57	114	10	1	0	ok
1220	2026-08-01 05:15:36.542866+00	0.28	0	1906	1243	0	20	57	114	11	1	0	ok
1221	2026-08-01 05:16:36.542781+00	0.1	0	1906	1239	0	20	57	113	10	1	0	ok
1222	2026-08-01 05:17:36.54398+00	0.04	0.5	1906	1241	0	20	57	114	10	1	0	ok
1223	2026-08-01 05:18:36.544094+00	0.01	0	1906	1245	0	20	57	114	10	1	0	ok
1224	2026-08-01 05:19:36.546857+00	0.31	0	1906	1239	0	20	57	114	12	1	0	ok
1225	2026-08-01 05:20:36.546076+00	0.38	0	1906	1245	0	20	57	114	10	1	0	ok
1226	2026-08-01 05:21:36.54853+00	0.14	0	1906	1253	0	20	57	114	10	1	0	ok
1227	2026-08-01 05:22:36.54851+00	0.05	0	1906	1252	0	20	57	115	10	1	0	ok
1228	2026-08-01 05:23:36.55028+00	0.02	0	1906	1239	0	20	57	114	13	1	0	ok
1229	2026-08-01 05:24:36.549996+00	0	0	1906	1251	0	20	57	114	11	1	0	ok
1230	2026-08-01 05:25:36.552462+00	0.45	0	1906	1249	0	20	57	114	11	1	0	ok
1231	2026-08-01 05:26:36.553178+00	0.16	0	1906	1235	0	20	57	115	11	1	0	ok
1232	2026-08-01 05:27:36.553458+00	0.37	0	1906	1243	0	20	57	114	11	1	0	ok
1233	2026-08-01 05:28:36.555542+00	0.13	0	1906	1237	0	20	57	115	11	1	0	ok
1234	2026-08-01 05:29:36.555368+00	0.05	0	1906	1237	0	20	57	114	14	1	0	ok
1235	2026-08-01 05:30:36.556147+00	0.02	0	1906	1252	0	20	57	114	11	1	0	ok
1236	2026-08-01 05:31:36.557418+00	0.04	0	1906	1240	0	20	57	114	12	1	0	ok
1237	2026-08-01 05:32:36.559655+00	0.01	0	1906	1240	0	20	57	115	11	1	0	ok
1238	2026-08-01 05:33:36.558987+00	0	0	1906	1248	0	20	57	115	13	1	0	ok
1239	2026-08-01 05:34:36.55994+00	0	0	1906	1247	0	20	57	114	11	1	0	ok
1240	2026-08-01 05:35:36.560624+00	0.32	0	1906	1250	0	20	57	114	12	1	0	ok
1241	2026-08-01 05:36:36.560756+00	0.21	0	1906	1250	0	20	57	115	11	1	0	ok
1242	2026-08-01 05:37:36.560862+00	0.51	0.5	1906	1245	0	20	57	115	12	1	0	ok
1243	2026-08-01 05:38:36.559738+00	0.19	0	1906	1249	0	20	57	114	11	1	0	ok
1244	2026-08-01 05:39:36.560709+00	0.07	0	1906	1248	0	20	57	114	12	1	0	ok
1245	2026-08-01 05:40:36.561796+00	0.22	0	1906	1243	0	20	57	114	11	1	0	ok
1246	2026-08-01 05:41:36.5606+00	0.08	0	1906	1247	0	20	57	115	11	1	0	ok
1247	2026-08-01 05:42:36.560422+00	0.08	0	1906	1253	0	20	57	114	10	1	0	ok
1248	2026-08-01 05:43:36.560103+00	0.27	0	1906	1239	0	20	57	114	10	1	0	ok
1249	2026-08-01 05:44:36.560289+00	0.1	0	1906	1235	0	20	57	114	10	1	0	ok
1250	2026-08-01 05:45:36.559754+00	0.03	0	1906	1248	0	20	57	115	10	1	0	ok
1251	2026-08-01 05:46:36.561613+00	0.06	0	1906	1248	0	20	57	112	10	1	0	ok
1252	2026-08-01 05:47:36.560449+00	0.07	0	1906	1240	0	20	57	113	10	1	0	ok
1253	2026-08-01 05:48:36.559381+00	0.06	0	1906	1255	0	20	57	112	10	1	0	ok
1254	2026-08-01 05:49:36.559019+00	0.07	0	1906	1253	0	20	57	112	10	1	0	ok
1255	2026-08-01 05:50:36.561284+00	0.27	0	1906	1237	0	20	57	113	10	1	0	ok
1256	2026-08-01 05:51:36.561024+00	0.1	0	1906	1250	0	20	57	114	10	1	0	ok
1257	2026-08-01 05:52:36.563701+00	0.03	0	1906	1250	0	20	57	113	10	1	0	ok
1258	2026-08-01 05:53:36.561517+00	0.06	0	1906	1245	0	20	57	114	10	1	0	ok
1259	2026-08-01 05:54:36.561884+00	0.21	0	1906	1242	0	20	57	114	10	1	0	ok
1260	2026-08-01 05:55:36.562266+00	0.22	0	1906	1247	0	20	57	114	10	1	0	ok
1261	2026-08-01 05:56:36.561677+00	0.11	0	1906	1244	0	20	57	113	10	1	0	ok
1262	2026-08-01 05:57:36.560982+00	0.09	0	1906	1247	0	20	57	114	10	1	0	ok
1263	2026-08-01 05:58:36.563015+00	0.22	0	1906	1242	0	20	57	114	10	1	0	ok
1264	2026-08-01 05:59:36.56333+00	0.32	0	1906	1234	0	20	57	114	10	1	0	ok
1265	2026-08-01 06:00:36.562869+00	0.12	0	1906	1249	0	20	57	114	10	1	0	ok
1266	2026-08-01 06:01:36.562754+00	0.09	0	1906	1248	0	20	57	114	10	1	0	ok
1267	2026-08-01 06:02:36.562976+00	0.34	0	1906	1253	0	20	57	114	10	1	0	ok
1268	2026-08-01 06:03:36.566267+00	0.37	0	1906	1240	0	20	57	114	11	1	0	ok
1269	2026-08-01 06:04:36.564155+00	0.41	0	1906	1238	0	20	57	114	10	1	0	ok
1270	2026-08-01 06:05:36.56638+00	0.73	0	1906	1238	0	20	57	114	11	1	0	ok
1271	2026-08-01 06:06:36.565809+00	0.32	0	1906	1238	0	20	57	114	13	1	0	ok
1272	2026-08-01 06:07:36.564969+00	0.66	0	1906	1246	0	20	57	115	12	1	0	ok
1273	2026-08-01 06:08:36.56696+00	0.29	0	1906	1237	0	20	57	114	18	1	0	ok
1274	2026-08-01 06:09:36.566472+00	0.35	0	1906	1243	0	20	57	114	11	1	0	ok
1275	2026-08-01 06:10:36.568304+00	0.27	0	1906	1235	0	20	57	114	10	1	0	ok
1276	2026-08-01 06:11:36.568293+00	0.1	0	1906	1243	0	20	57	114	11	1	0	ok
1277	2026-08-01 06:12:36.568157+00	0.08	0	1906	1237	0	20	57	109	10	1	0	ok
1278	2026-08-01 06:13:36.568354+00	0.13	0	1906	1247	0	20	57	114	10	1	0	ok
1279	2026-08-01 06:14:36.572242+00	0.29	0	1906	1231	0	20	57	117	10	1	0	ok
1280	2026-08-01 06:15:36.568234+00	0.15	0	1906	1235	0	20	57	116	10	1	0	ok
1281	2026-08-01 06:16:36.56879+00	0.1	0	1906	1227	0	20	57	117	12	1	0	ok
1282	2026-08-01 06:17:36.569834+00	0.08	0	1906	1238	0	20	57	117	13	1	0	ok
1283	2026-08-01 06:18:36.570615+00	0.17	0	1906	1240	0	20	57	119	8	1	0	ok
1284	2026-08-01 06:19:36.569498+00	0.37	0	1906	1237	0	20	57	120	10	1	0	ok
1285	2026-08-01 06:20:36.571147+00	0.13	0	1906	1238	0	20	57	119	11	1	0	ok
1286	2026-08-01 06:21:36.57236+00	0.1	0	1906	1236	0	20	57	120	12	1	0	ok
1287	2026-08-01 06:22:36.573325+00	0.08	0	1906	1233	0	20	57	120	10	1	0	ok
1288	2026-08-01 06:23:36.573116+00	0.16	0	1906	1247	0	20	57	119	10	1	0	ok
1289	2026-08-01 06:24:36.572615+00	0.15	0	1906	1238	0	20	57	120	11	1	0	ok
1290	2026-08-01 06:25:36.571456+00	0.3	0	1906	1231	0	20	57	120	10	1	0	ok
1291	2026-08-01 06:26:36.572759+00	0.2	0	1906	1235	0	20	57	120	12	1	0	ok
1292	2026-08-01 06:27:36.573883+00	0.27	0	1906	1234	0	20	57	120	10	1	0	ok
1293	2026-08-01 06:28:36.573651+00	0.42	0.5	1906	1238	0	20	57	120	10	1	0	ok
1294	2026-08-01 06:29:36.576597+00	0.4	0	1906	1237	0	20	57	120	11	1	0	ok
1295	2026-08-01 06:30:36.575906+00	0.68	0	1906	1239	0	20	57	120	12	1	0	ok
1296	2026-08-01 06:31:36.577282+00	0.3	0	1906	1236	0	20	57	121	13	1	0	ok
1297	2026-08-01 06:32:36.577428+00	0.2	0	1906	1235	0	20	57	120	10	1	0	ok
1298	2026-08-01 06:33:36.579477+00	0.48	0	1906	1244	0	20	57	120	12	1	0	ok
1299	2026-08-01 06:34:36.580845+00	0.42	0	1906	1231	0	20	57	120	11	1	0	ok
1300	2026-08-01 06:35:36.579678+00	0.2	0	1906	1227	0	20	57	120	11	1	0	ok
1301	2026-08-01 06:36:36.581043+00	0.46	0	1906	1230	0	20	57	120	12	1	0	ok
1302	2026-08-01 06:37:36.581154+00	0.22	0	1906	1240	0	20	57	120	9	1	0	ok
1303	2026-08-01 06:38:36.582418+00	0.13	0	1906	1231	0	20	57	120	15	1	0	ok
1304	2026-08-01 06:39:36.585987+00	0.24	0	1906	1234	0	20	57	120	13	1	0	ok
1305	2026-08-01 06:40:36.585336+00	0.33	0	1906	1229	0	20	57	120	12	1	0	ok
1306	2026-08-01 06:41:36.585179+00	0.17	0.5	1906	1228	0	20	57	120	10	1	0	ok
1307	2026-08-01 06:42:36.586233+00	0.25	0	1906	1232	0	20	57	121	10	1	0	ok
1308	2026-08-01 06:43:36.588286+00	0.14	0	1906	1235	0	20	57	120	10	1	0	ok
1309	2026-08-01 06:44:36.587273+00	0.14	0	1906	1234	0	20	57	121	10	1	0	ok
1310	2026-08-01 06:45:36.58735+00	0.25	0	1906	1234	0	20	57	121	10	1	0	ok
1311	2026-08-01 06:46:36.591677+00	0.14	0	1906	1229	0	20	57	121	11	1	0	ok
1312	2026-08-01 06:47:36.590054+00	0.1	0	1906	1235	0	20	57	121	10	1	0	ok
1313	2026-08-01 06:48:36.592035+00	0.6	0	1906	1231	0	20	57	123	10	1	0	ok
1314	2026-08-01 06:49:36.591614+00	0.22	0	1906	1225	0	20	57	122	10	1	0	ok
1315	2026-08-01 06:50:36.592969+00	0.27	0	1906	1237	0	20	57	122	10	1	0	ok
1316	2026-08-01 06:51:36.593976+00	0.24	0.5	1906	1243	0	20	57	115	11	1	0	ok
1317	2026-08-01 06:52:36.597499+00	0.14	0	1906	1247	0	20	57	116	11	1	0	ok
1318	2026-08-01 06:53:36.598511+00	0.1	0	1906	1230	0	20	57	120	19	1	0	ok
1319	2026-08-01 06:54:36.596603+00	0.33	0	1906	1245	0	20	57	120	10	1	0	ok
1320	2026-08-01 06:55:36.609387+00	0.49	0	1906	1231	2	20	56	120	14	1	0	ok
1321	2026-08-01 06:56:36.596225+00	0.3	0	1906	1231	2	20	56	120	12	1	0	ok
1322	2026-08-01 06:57:36.596548+00	0.16	0	1906	1227	2	20	56	121	9	1	0	ok
1323	2026-08-01 06:58:36.598125+00	0.1	0	1906	1229	2	20	56	121	9	1	0	ok
1324	2026-08-01 06:59:36.597168+00	0.08	0	1906	1227	2	20	56	121	11	1	0	ok
1325	2026-08-01 07:00:36.598644+00	0.17	0.5	1906	1235	2	20	56	122	10	1	0	ok
1326	2026-08-01 07:01:36.598039+00	0.21	0	1906	1231	2	20	56	122	12	1	0	ok
1327	2026-08-01 07:02:36.597097+00	0.12	0	1906	1241	0	20	56	121	11	1	0	ok
1328	2026-08-01 07:03:36.598866+00	0.09	0	1906	1250	0	20	56	123	10	1	0	ok
1329	2026-08-01 07:04:36.597624+00	0.08	0	1906	1249	0	20	56	122	9	1	0	ok
1330	2026-08-01 07:05:36.597825+00	0.08	0	1906	1257	0	20	56	122	10	1	0	ok
1331	2026-08-01 07:06:36.598956+00	0.27	0	1906	1244	0	20	56	123	12	1	0	ok
1332	2026-08-01 07:07:36.598071+00	0.1	0	1906	1246	0	20	56	122	10	1	0	ok
1333	2026-08-01 07:08:36.59866+00	0.08	0	1906	1246	0	20	56	123	10	1	0	ok
1334	2026-08-01 07:09:36.597388+00	0.08	0	1906	1260	0	20	56	123	10	1	0	ok
1335	2026-08-01 07:10:36.599243+00	0.08	0	1906	1257	0	20	56	123	10	1	0	ok
1336	2026-08-01 07:11:36.597881+00	0.11	0	1906	1242	0	20	56	123	11	1	0	ok
1337	2026-08-01 07:12:36.601412+00	0.09	0	1906	1242	0	20	56	123	11	1	0	ok
1338	2026-08-01 07:13:36.5985+00	0.08	0	1906	1252	0	20	56	125	10	1	0	ok
1339	2026-08-01 07:14:36.599964+00	0.08	0	1906	1241	0	20	56	126	10	1	0	ok
1340	2026-08-01 07:15:36.599342+00	0.37	0	1906	1251	0	20	56	124	10	1	0	ok
1341	2026-08-01 07:16:36.60064+00	0.23	0	1906	1246	0	20	56	123	11	1	0	ok
1342	2026-08-01 07:17:36.601177+00	0.13	0	1906	1244	0	20	57	124	10	1	0	ok
1343	2026-08-01 07:18:36.607242+00	0.1	0	1906	1246	0	20	57	124	10	1	0	ok
1344	2026-08-01 07:19:36.604089+00	0.08	0	1906	1241	0	20	57	125	10	1	0	ok
1345	2026-08-01 07:20:36.603916+00	0.22	0	1906	1250	0	20	57	123	10	1	0	ok
1346	2026-08-01 07:21:36.604083+00	0.13	0	1906	1249	0	20	57	126	10	1	0	ok
1347	2026-08-01 07:22:25.677041+00	0.24	0	1906	1293	0	20	57	99	12	1	0	ok
1348	2026-08-01 07:23:25.709243+00	0.2	0	1906	1263	0	20	57	96	15	1	0	ok
1349	2026-08-01 07:24:25.682478+00	0.13	0.5	1906	1252	0	20	57	102	16	1	0	ok
1350	2026-08-01 07:25:25.682457+00	0.1	0	1906	1261	0	20	57	100	14	1	0	ok
1351	2026-08-01 07:26:25.682612+00	0.09	0	1906	1252	0	20	57	104	15	1	0	ok
1352	2026-08-01 07:27:25.681902+00	0.09	0	1906	1258	0	20	57	106	14	1	0	ok
1353	2026-08-01 07:28:25.682507+00	0.15	0	1906	1248	0	20	57	106	14	1	0	ok
1354	2026-08-01 07:29:25.682219+00	0.11	0	1906	1249	0	20	57	107	15	1	0	ok
1355	2026-08-01 07:30:25.683269+00	0.31	0	1906	1246	0	20	57	108	17	1	0	ok
1356	2026-08-01 07:31:25.682984+00	0.23	0	1906	1239	0	20	57	108	17	1	0	ok
1357	2026-08-01 07:32:25.683267+00	0.14	0	1906	1245	0	20	57	108	17	1	0	ok
1358	2026-08-01 07:33:25.683468+00	0.31	0	1906	1239	0	20	57	108	18	1	0	ok
1359	2026-08-01 07:34:25.683732+00	0.17	0	1906	1231	0	20	57	109	18	1	0	ok
1360	2026-08-01 07:35:25.684734+00	0.12	0.5	1906	1245	0	20	57	108	18	1	0	ok
1361	2026-08-01 07:36:25.683922+00	0.1	0	1906	1236	0	20	57	109	19	1	0	ok
1362	2026-08-01 07:37:25.683923+00	0.09	0	1906	1238	0	20	57	108	18	1	0	ok
1363	2026-08-01 07:38:25.682459+00	0.09	0.5	1906	1243	0	20	57	109	17	1	0	ok
1364	2026-08-01 07:39:25.682784+00	0.09	0	1906	1233	0	20	57	109	15	1	0	ok
1365	2026-08-01 07:40:25.685913+00	0.2	0	1906	1248	0	20	57	102	17	1	0	ok
1366	2026-08-01 07:41:25.684587+00	0.13	0	1906	1239	0	20	57	108	17	1	0	ok
1367	2026-08-01 07:42:25.685477+00	0.1	0	1906	1237	0	20	57	110	17	1	0	ok
1368	2026-08-01 07:43:25.684858+00	0.09	0	1906	1233	0	20	57	110	16	1	0	ok
1369	2026-08-01 07:44:25.687653+00	0.15	0	1906	1233	0	20	57	111	18	1	0	ok
1370	2026-08-01 07:45:25.684699+00	0.17	0.5	1906	1231	0	20	57	112	17	1	0	ok
1371	2026-08-01 07:46:25.68698+00	0.17	0	1906	1232	0	20	57	112	18	1	0	ok
1372	2026-08-01 07:47:25.686728+00	0.12	0	1906	1239	0	20	57	112	15	1	0	ok
1373	2026-08-01 07:48:25.685566+00	0.1	0	1906	1242	0	20	57	112	16	1	0	ok
1374	2026-08-01 07:49:25.689854+00	0.15	0	1906	1236	0	20	57	112	16	1	0	ok
1375	2026-08-01 07:50:25.69499+00	0.05	0	1906	1231	0	20	57	112	16	1	0	ok
1376	2026-08-01 07:51:25.685033+00	0.08	0	1906	1238	0	20	57	112	16	1	0	ok
1377	2026-08-01 07:52:25.687028+00	0.08	0	1906	1234	0	20	57	114	15	1	0	ok
1378	2026-08-01 07:53:25.686631+00	0.03	0	1906	1231	0	20	57	112	16	1	0	ok
1379	2026-08-01 07:54:25.687111+00	0.12	0	1906	1233	0	20	57	113	16	1	0	ok
1380	2026-08-01 07:55:25.688274+00	0.1	0	1906	1232	0	20	57	112	14	1	0	ok
1381	2026-08-01 07:56:25.687517+00	0.09	0	1906	1236	0	20	57	112	14	1	0	ok
1382	2026-08-01 07:57:25.686769+00	0.09	0	1906	1237	0	20	57	112	16	1	0	ok
1383	2026-08-01 07:58:25.689216+00	0.09	0	1906	1237	0	20	57	112	13	1	0	ok
1384	2026-08-01 07:59:25.68833+00	0.09	0	1906	1243	0	20	57	112	13	1	0	ok
1385	2026-08-01 08:00:25.689249+00	0.15	0	1906	1231	0	20	57	119	17	1	0	ok
1386	2026-08-01 08:01:25.689593+00	0.28	0	1906	1225	0	20	57	118	17	1	0	ok
1387	2026-08-01 08:02:25.690305+00	0.16	0	1906	1228	0	20	57	119	15	1	0	ok
1388	2026-08-01 08:03:25.690282+00	0.11	0	1906	1223	0	20	57	119	14	1	0	ok
1389	2026-08-01 08:04:25.689599+00	0.33	0	1906	1225	0	20	57	118	14	1	0	ok
1390	2026-08-01 08:05:25.69+00	0.17	0	1906	1222	0	20	57	118	18	1	0	ok
1391	2026-08-01 08:06:25.691517+00	0.12	0	1906	1226	0	20	57	118	18	1	0	ok
1392	2026-08-01 08:07:25.69116+00	0.32	0	1906	1231	0	20	57	118	17	1	0	ok
1393	2026-08-01 08:08:25.691749+00	0.17	0	1906	1230	0	20	57	118	18	1	0	ok
1394	2026-08-01 08:09:25.692286+00	0.23	0	1906	1231	0	20	57	118	17	1	0	ok
1395	2026-08-01 08:10:25.692135+00	0.14	0	1906	1233	0	20	57	118	18	1	0	ok
1396	2026-08-01 08:11:25.691811+00	0.11	0	1906	1239	0	20	57	119	14	1	0	ok
1397	2026-08-01 08:12:25.691354+00	0.1	0	1906	1227	0	20	57	119	17	1	0	ok
1398	2026-08-01 08:13:25.695715+00	0.09	0	1906	1234	0	20	57	119	15	1	0	ok
1399	2026-08-01 08:14:25.697461+00	0.09	0	1906	1227	0	20	57	119	16	1	0	ok
1400	2026-08-01 08:15:25.696703+00	0.38	0	1906	1229	0	20	57	119	14	1	0	ok
1401	2026-08-01 08:16:25.696785+00	0.23	0	1906	1231	0	20	57	119	16	1	0	ok
1402	2026-08-01 08:17:25.697316+00	0.14	0	1906	1241	0	20	57	119	12	1	0	ok
1403	2026-08-01 08:18:25.698743+00	0.18	0	1906	1238	0	20	57	119	15	1	0	ok
1404	2026-08-01 08:19:25.695942+00	0.12	0	1906	1219	0	20	57	119	13	1	0	ok
1405	2026-08-01 08:20:25.695679+00	0.21	0	1906	1223	0	20	57	119	14	1	0	ok
1406	2026-08-01 08:21:25.696502+00	0.48	0	1906	1214	0	20	57	119	13	1	0	ok
1407	2026-08-01 08:22:25.695441+00	0.17	0	1906	1237	0	20	57	119	11	1	0	ok
1408	2026-08-01 08:23:25.69611+00	0.12	0	1906	1223	0	20	57	118	15	1	0	ok
1409	2026-08-01 08:24:25.696153+00	0.1	0	1906	1238	0	20	57	118	12	1	0	ok
1410	2026-08-01 08:25:25.697349+00	0.09	0	1906	1232	0	20	57	118	15	1	0	ok
1411	2026-08-01 08:26:25.69744+00	0.18	0	1906	1233	0	20	57	118	13	1	0	ok
1412	2026-08-01 08:27:25.695813+00	0.07	0	1906	1231	0	20	57	118	13	1	0	ok
1413	2026-08-01 08:28:25.696593+00	0.02	0	1906	1228	0	20	57	117	16	1	0	ok
1414	2026-08-01 08:29:25.698528+00	0.01	0	1906	1237	0	20	57	118	11	1	0	ok
1415	2026-08-01 08:30:25.69871+00	0.12	0	1906	1239	0	20	57	118	12	1	0	ok
1416	2026-08-01 08:31:25.699546+00	0.1	0	1906	1231	0	20	57	117	15	1	0	ok
1417	2026-08-01 08:32:25.699461+00	0.09	0	1906	1233	0	20	57	118	16	1	0	ok
1418	2026-08-01 08:33:25.700367+00	0.09	0	1906	1231	0	20	57	118	17	1	0	ok
1419	2026-08-01 08:34:25.699567+00	0.26	0	1906	1229	0	20	57	118	16	1	0	ok
1420	2026-08-01 08:35:25.700836+00	0.09	0	1906	1239	0	20	57	117	14	1	0	ok
1421	2026-08-01 08:36:25.700684+00	0.09	0	1906	1229	0	20	57	117	15	1	0	ok
1422	2026-08-01 08:37:25.698563+00	0.09	0	1906	1237	0	20	57	118	14	1	0	ok
1423	2026-08-01 08:38:25.699328+00	0.09	0	1906	1233	0	20	57	118	14	1	0	ok
1424	2026-08-01 08:39:25.699693+00	0.09	0	1906	1228	0	20	57	118	13	1	0	ok
1425	2026-08-01 08:40:25.700762+00	0.09	0	1906	1232	0	20	57	117	13	1	0	ok
1426	2026-08-01 08:41:25.699646+00	0.09	0	1906	1236	0	20	57	119	13	1	0	ok
1427	2026-08-01 08:42:25.701043+00	0.14	0	1906	1229	0	20	57	118	13	1	0	ok
1428	2026-08-01 08:43:25.701352+00	0.28	0	1906	1237	0	20	57	121	14	1	0	ok
1429	2026-08-01 08:44:25.700647+00	0.1	0	1906	1228	0	20	57	121	18	1	0	ok
1430	2026-08-01 08:45:25.70295+00	0.09	0	1906	1229	0	20	57	120	17	1	0	ok
1431	2026-08-01 08:46:25.704227+00	0.09	0	1906	1233	0	20	57	120	16	1	0	ok
1432	2026-08-01 08:47:25.702627+00	0.03	0	1906	1221	0	20	57	121	14	1	0	ok
1433	2026-08-01 08:48:25.7019+00	0.07	0	1906	1239	0	20	57	121	13	1	0	ok
1434	2026-08-01 08:49:25.703058+00	0.02	0	1906	1225	0	20	57	121	17	1	0	ok
1435	2026-08-01 08:50:25.70724+00	0.1	0	1906	1223	0	20	57	121	17	1	0	ok
1436	2026-08-01 08:51:25.706534+00	0.04	0	1906	1230	0	20	57	121	17	1	0	ok
1437	2026-08-01 08:52:25.70634+00	0.01	0	1906	1225	0	20	57	121	15	1	0	ok
1438	2026-08-01 08:53:25.707594+00	0	0	1906	1229	0	20	57	121	14	1	0	ok
1439	2026-08-01 08:54:25.706379+00	0.06	0	1906	1231	0	20	57	121	15	1	0	ok
1440	2026-08-01 08:55:25.707316+00	0.08	0	1906	1235	0	20	57	121	13	1	0	ok
1441	2026-08-01 08:56:25.707038+00	0.03	0	1906	1236	0	20	57	121	12	1	0	ok
1442	2026-08-01 08:57:25.70754+00	0.07	0	1906	1237	0	20	57	120	12	1	0	ok
1443	2026-08-01 08:58:25.706432+00	0.11	0	1906	1233	0	20	57	121	12	1	0	ok
1444	2026-08-01 08:59:25.707616+00	0.04	0	1906	1231	0	20	57	120	12	1	0	ok
1445	2026-08-01 09:00:25.708576+00	0.07	0	1906	1237	0	20	57	120	12	1	0	ok
1446	2026-08-01 09:01:25.709759+00	0.08	0	1906	1234	0	20	57	121	12	1	0	ok
1447	2026-08-01 09:02:25.709611+00	0.03	0	1906	1235	0	20	57	121	12	1	0	ok
1448	2026-08-01 09:03:25.714443+00	0.06	0	1906	1239	0	20	57	121	12	1	0	ok
1449	2026-08-01 09:04:25.714401+00	0.08	0	1906	1233	0	20	57	121	15	1	0	ok
1450	2026-08-01 09:05:25.71319+00	0.03	0	1906	1229	0	20	57	121	14	1	0	ok
1451	2026-08-01 09:06:25.713691+00	0.07	0	1906	1224	0	20	57	121	15	1	0	ok
1452	2026-08-01 09:07:25.713452+00	0.02	0	1906	1233	0	20	57	121	14	1	0	ok
1453	2026-08-01 09:08:25.713546+00	0.01	0	1906	1224	0	20	57	121	15	1	0	ok
1454	2026-08-01 09:09:25.712837+00	0	0	1906	1233	0	20	57	121	14	1	0	ok
1455	2026-08-01 09:10:25.714272+00	0.11	0	1906	1223	0	20	57	121	18	1	0	ok
1456	2026-08-01 09:11:25.715663+00	0.04	0	1906	1223	0	20	57	121	17	1	0	ok
1457	2026-08-01 09:12:25.71576+00	0.07	0	1906	1215	0	20	57	122	18	1	0	ok
1458	2026-08-01 09:13:25.716966+00	0.02	0	1906	1225	0	20	57	121	17	1	0	ok
1459	2026-08-01 09:14:25.716514+00	0.01	0	1906	1228	0	20	57	121	18	1	0	ok
1460	2026-08-01 09:15:25.718409+00	0.11	0	1906	1226	0	20	57	121	17	1	0	ok
1461	2026-08-01 09:16:25.719102+00	0.04	0	1906	1224	0	20	57	121	18	1	0	ok
1462	2026-08-01 09:17:25.719812+00	0.01	0	1906	1228	0	20	57	112	17	1	0	ok
1463	2026-08-01 09:18:25.721447+00	0	0	1906	1229	0	20	57	115	18	1	0	ok
1464	2026-08-01 09:19:25.72106+00	0.05	0	1906	1229	0	20	57	116	17	1	0	ok
1465	2026-08-01 09:20:25.721452+00	0.02	0	1906	1235	0	20	57	118	18	1	0	ok
1466	2026-08-01 09:21:25.723072+00	0	0	1906	1231	0	20	57	119	17	1	0	ok
1467	2026-08-01 09:22:25.723743+00	0	0	1906	1230	0	20	57	121	18	1	0	ok
1468	2026-08-01 09:23:25.727104+00	0	0	1906	1224	0	20	57	119	17	1	0	ok
1469	2026-08-01 09:24:25.726106+00	0.06	0	1906	1232	0	20	57	119	18	1	0	ok
1470	2026-08-01 09:25:25.725707+00	0.02	0	1906	1230	0	20	57	119	15	1	0	ok
1471	2026-08-01 09:26:25.726375+00	0	0	1906	1244	0	20	57	119	14	1	0	ok
1472	2026-08-01 09:27:25.729186+00	0	0	1906	1232	0	20	57	119	14	1	0	ok
1473	2026-08-01 09:28:25.731661+00	0	0	1906	1228	0	20	57	120	16	1	0	ok
1474	2026-08-01 09:29:25.730684+00	0	0	1906	1229	0	20	57	119	15	1	0	ok
1475	2026-08-01 09:30:25.731316+00	0.06	0	1906	1228	0	20	57	120	13	1	0	ok
1476	2026-08-01 09:31:25.733435+00	0.02	0	1906	1234	0	20	57	120	14	1	0	ok
1477	2026-08-01 09:32:25.732883+00	0	0	1906	1229	0	20	57	119	12	1	0	ok
1478	2026-08-01 09:33:25.733324+00	0	0	1906	1239	0	20	57	120	13	1	0	ok
1479	2026-08-01 09:34:25.734509+00	0	0	1906	1238	0	20	57	120	15	1	0	ok
1480	2026-08-01 09:35:25.73564+00	0	0	1906	1245	0	20	57	120	12	1	0	ok
1481	2026-08-01 09:36:25.736272+00	0	0	1906	1234	0	20	57	120	14	1	0	ok
1482	2026-08-01 09:37:25.73628+00	0	0	1906	1241	0	20	57	119	13	1	0	ok
1483	2026-08-01 09:38:25.737176+00	0.06	0	1906	1235	0	20	57	120	13	1	0	ok
1484	2026-08-01 09:39:25.737621+00	0.02	0.5	1906	1239	0	20	57	120	15	1	0	ok
1485	2026-08-01 09:40:25.740964+00	0.01	0	1906	1240	0	20	57	120	17	1	0	ok
1486	2026-08-01 09:41:25.741519+00	0	0	1906	1235	0	20	57	119	17	1	0	ok
1487	2026-08-01 09:42:25.740832+00	0	0	1906	1246	0	20	57	120	15	1	0	ok
1488	2026-08-01 09:43:25.740533+00	0	0	1906	1249	0	20	57	120	14	1	0	ok
1489	2026-08-01 09:44:25.739818+00	0	0	1906	1242	0	20	57	120	17	1	0	ok
1490	2026-08-01 09:45:25.740479+00	0	0	1906	1245	0	20	57	120	16	1	0	ok
1491	2026-08-01 09:46:25.741034+00	0	0	1906	1231	0	20	57	120	18	1	0	ok
1492	2026-08-01 09:47:25.740716+00	0	0	1906	1244	0	20	57	120	17	1	0	ok
1493	2026-08-01 09:48:25.741366+00	0	0	1906	1247	0	20	57	120	16	1	0	ok
1494	2026-08-01 09:49:25.740535+00	0	0	1906	1238	0	20	57	120	17	1	0	ok
1495	2026-08-01 09:50:25.74104+00	0	0	1906	1239	0	20	57	120	16	1	0	ok
1496	2026-08-01 09:51:25.741166+00	0	0	1906	1242	0	20	57	120	13	1	0	ok
1497	2026-08-01 09:52:25.741082+00	0	0	1906	1245	0	20	57	120	12	1	0	ok
1498	2026-08-01 09:53:25.742179+00	0	0	1906	1241	0	20	57	120	12	1	0	ok
1499	2026-08-01 09:54:25.742177+00	0	0	1906	1250	0	20	57	120	12	1	0	ok
1500	2026-08-01 09:55:25.742032+00	0	0	1906	1249	0	20	57	120	13	1	0	ok
1501	2026-08-01 09:56:25.743085+00	0	0	1906	1248	0	20	57	121	13	1	0	ok
1502	2026-08-01 09:57:25.742111+00	0	0	1906	1244	0	20	57	120	13	1	0	ok
1503	2026-08-01 09:58:25.742547+00	0	0	1906	1255	0	20	57	120	12	1	0	ok
1504	2026-08-01 09:59:25.743495+00	0.4	0	1906	1245	0	20	57	120	13	1	0	ok
1505	2026-08-01 10:00:25.74365+00	0.48	0	1906	1248	0	20	57	120	13	1	0	ok
1506	2026-08-01 10:01:25.744677+00	0.33	0	1906	1247	0	20	57	121	14	1	0	ok
1507	2026-08-01 10:02:25.74357+00	0.12	0.5	1906	1239	0	20	57	120	13	1	0	ok
1508	2026-08-01 10:03:25.748383+00	0.1	0	1906	1232	0	20	57	120	16	1	0	ok
1509	2026-08-01 10:04:25.746364+00	0.12	0	1906	1244	0	20	57	120	16	1	0	ok
1510	2026-08-01 10:05:25.746893+00	0.04	0	1906	1246	0	20	57	120	17	1	0	ok
1511	2026-08-01 10:06:25.746496+00	0.01	0	1906	1244	0	20	57	120	18	1	0	ok
1512	2026-08-01 10:07:25.746525+00	0	0	1906	1245	0	20	57	120	17	1	0	ok
1513	2026-08-01 10:08:25.747167+00	0	0	1906	1245	0	20	57	120	18	1	0	ok
1514	2026-08-01 10:09:25.747093+00	0	0	1906	1242	0	20	57	120	17	1	0	ok
1515	2026-08-01 10:10:25.754866+00	0.06	0	1906	1241	0	20	57	120	18	1	0	ok
1516	2026-08-01 10:11:25.747376+00	0.02	0	1906	1242	0	20	57	121	17	1	0	ok
1517	2026-08-01 10:12:25.747763+00	0.01	0	1906	1245	0	20	57	120	18	1	0	ok
1518	2026-08-01 10:13:25.748804+00	0	0	1906	1237	0	20	57	120	17	1	0	ok
1519	2026-08-01 10:14:25.746396+00	0	0	1906	1244	0	20	57	121	18	1	0	ok
1520	2026-08-01 10:15:25.748092+00	0	0	1906	1252	0	20	57	121	11	1	0	ok
1521	2026-08-01 10:16:25.747798+00	0	0.5	1906	1254	0	20	57	120	11	1	0	ok
1522	2026-08-01 10:17:25.748003+00	0	0	1906	1248	0	20	57	121	14	1	0	ok
1523	2026-08-01 10:18:25.749344+00	0	0	1906	1235	0	20	57	120	18	1	0	ok
1524	2026-08-01 10:19:25.749529+00	0	0	1906	1246	0	20	57	121	15	1	0	ok
1525	2026-08-01 10:20:25.748315+00	0	0	1906	1242	0	20	57	121	18	1	0	ok
1526	2026-08-01 10:21:25.748463+00	0	0	1906	1236	0	20	57	120	17	1	0	ok
1527	2026-08-01 10:22:25.74944+00	0	0	1906	1248	0	20	57	120	18	1	0	ok
1528	2026-08-01 10:23:25.749495+00	0	0	1906	1242	0	20	57	120	15	1	0	ok
1529	2026-08-01 10:24:25.749344+00	0	0	1906	1243	0	20	57	120	17	1	0	ok
1530	2026-08-01 10:25:25.751673+00	0	0	1906	1248	0	20	57	120	15	1	0	ok
1531	2026-08-01 10:26:25.750064+00	0	0	1906	1246	0	20	57	121	18	1	0	ok
1532	2026-08-01 10:27:25.753357+00	0.11	0	1906	1251	0	20	57	121	15	1	0	ok
1533	2026-08-01 10:28:25.755728+00	0.04	0	1906	1245	0	20	57	121	17	1	0	ok
1534	2026-08-01 10:29:25.756392+00	0.09	0	1906	1239	0	20	57	121	15	1	0	ok
1535	2026-08-01 10:30:25.756693+00	0.09	0	1906	1247	0	20	57	121	16	1	0	ok
1536	2026-08-01 10:31:25.755413+00	0.03	0	1906	1237	0	20	57	121	16	1	0	ok
1537	2026-08-01 10:32:25.756312+00	0.05	0	1906	1243	0	20	57	121	18	1	0	ok
1538	2026-08-01 10:33:25.757808+00	0.02	0	1906	1239	0	20	57	121	17	1	0	ok
1539	2026-08-01 10:34:25.756371+00	0	0	1906	1242	0	20	57	121	18	1	0	ok
1540	2026-08-01 10:35:25.757456+00	0	0	1906	1237	0	20	57	121	17	1	0	ok
1541	2026-08-01 10:36:25.760479+00	0	0.5	1906	1237	0	20	57	121	18	1	0	ok
1542	2026-08-01 10:37:25.759799+00	0	0	1906	1245	0	20	57	121	17	1	0	ok
1543	2026-08-01 10:38:25.759223+00	0	0	1906	1248	0	20	57	121	18	1	0	ok
1544	2026-08-01 10:39:25.759443+00	0	0	1906	1252	0	20	57	121	15	1	0	ok
1545	2026-08-01 10:40:25.760547+00	0	0	1906	1246	0	20	57	121	16	1	0	ok
1546	2026-08-01 10:41:25.76214+00	0	0	1906	1252	0	20	57	121	14	1	0	ok
1547	2026-08-01 10:42:25.762641+00	0	0	1906	1243	0	20	57	121	15	1	0	ok
1548	2026-08-01 10:43:25.760488+00	0	0	1906	1247	0	20	57	121	12	1	0	ok
1549	2026-08-01 10:44:25.760791+00	0	0	1906	1231	0	20	57	121	14	1	0	ok
1550	2026-08-01 10:45:25.761269+00	0.29	0	1906	1244	0	20	57	122	14	1	0	ok
1551	2026-08-01 10:46:25.763262+00	0.44	0	1906	1239	0	20	57	112	15	1	0	ok
1552	2026-08-01 10:47:25.764164+00	0.36	0	1906	1246	0	20	57	118	14	1	0	ok
1553	2026-08-01 10:48:25.765521+00	0.13	0	1906	1236	0	20	57	120	18	1	0	ok
1554	2026-08-01 10:49:25.7664+00	0.1	0	1906	1234	0	20	57	120	17	1	0	ok
1555	2026-08-01 10:50:25.767143+00	0.04	0	1906	1240	0	20	57	122	19	1	0	ok
1556	2026-08-01 10:51:25.768339+00	0.01	0	1906	1239	0	20	57	121	18	1	0	ok
1557	2026-08-01 10:52:25.770598+00	0	0	1906	1234	0	20	57	122	19	1	0	ok
1558	2026-08-01 10:53:25.770979+00	0	0	1906	1232	0	20	57	120	18	1	0	ok
1559	2026-08-01 10:54:25.771271+00	0	0	1906	1237	0	20	57	120	19	1	0	ok
1560	2026-08-01 10:55:25.772339+00	0	0	1906	1239	0	20	57	121	18	1	0	ok
1561	2026-08-01 10:56:25.773464+00	0	0.5	1906	1231	0	20	57	121	19	1	0	ok
1562	2026-08-01 10:57:25.777263+00	0	0	1906	1241	0	20	57	121	18	1	0	ok
1563	2026-08-01 10:58:25.77471+00	0.16	0	1906	1232	0	20	57	122	19	1	0	ok
1564	2026-08-01 10:59:25.776893+00	0.06	0.5	1906	1233	0	20	57	121	18	1	0	ok
1565	2026-08-01 11:00:25.777167+00	0.08	0	1906	1227	0	20	57	121	19	1	0	ok
1566	2026-08-01 11:01:25.780374+00	0.03	0	1906	1234	0	20	57	121	18	1	0	ok
1567	2026-08-01 11:02:25.779353+00	0.01	0	1906	1233	0	20	57	121	19	1	0	ok
1568	2026-08-01 11:03:25.779682+00	0	0	1906	1240	0	20	57	121	17	1	0	ok
1569	2026-08-01 11:04:25.780097+00	0	0	1906	1236	0	20	57	122	18	1	0	ok
1570	2026-08-01 11:05:25.782119+00	0	0.5	1906	1235	0	20	57	121	17	1	0	ok
1571	2026-08-01 11:06:25.781274+00	0	0	1906	1240	0	20	57	121	16	1	0	ok
1572	2026-08-01 11:07:25.786816+00	0	0	1906	1236	0	20	57	122	18	1	0	ok
1573	2026-08-01 11:08:25.784826+00	0	0	1906	1235	0	20	57	122	17	1	0	ok
1574	2026-08-01 11:09:25.786088+00	0	0	1906	1239	0	20	57	121	14	1	0	ok
1575	2026-08-01 11:10:25.785699+00	0	0	1906	1243	0	20	57	122	15	1	0	ok
1576	2026-08-01 11:11:25.788884+00	0	0	1906	1234	0	20	57	121	15	1	0	ok
1577	2026-08-01 11:12:25.789907+00	0	0	1906	1240	0	20	57	123	16	1	0	ok
1578	2026-08-01 11:13:25.788236+00	0	0	1906	1239	0	20	57	122	15	1	0	ok
1579	2026-08-01 11:14:25.791927+00	0	0	1906	1245	0	20	57	122	15	1	0	ok
1580	2026-08-01 11:15:25.790644+00	0.04	0	1906	1241	0	20	57	123	13	1	0	ok
1581	2026-08-01 11:16:25.791199+00	0.01	0	1906	1246	0	20	57	123	14	1	0	ok
1582	2026-08-01 11:17:25.790196+00	0	0	1906	1239	0	20	57	124	14	1	0	ok
1583	2026-08-01 11:18:25.790991+00	0	0	1906	1246	0	20	57	123	14	1	0	ok
1584	2026-08-01 11:19:25.791152+00	0	0	1906	1247	0	20	57	123	14	1	0	ok
1585	2026-08-01 11:20:25.791683+00	0	0	1906	1246	0	20	57	123	14	1	0	ok
1586	2026-08-01 11:21:25.790691+00	0	0.5	1906	1231	0	20	57	123	11	0	0	ok
1587	2026-08-01 11:22:25.789978+00	0	0	1906	1236	0	20	57	124	11	0	0	ok
1588	2026-08-01 11:23:25.790664+00	0	0	1906	1236	0	20	57	124	11	0	0	ok
1589	2026-08-01 11:24:25.792462+00	0	0	1906	1230	0	20	57	124	17	0	0	ok
1590	2026-08-01 11:25:25.793371+00	0	0	1906	1228	0	20	57	124	17	0	0	ok
1591	2026-08-01 11:26:25.793475+00	0.07	0	1906	1239	0	20	57	124	17	0	0	ok
1592	2026-08-01 11:27:25.792759+00	0.03	0	1906	1226	0	20	57	124	17	0	0	ok
1593	2026-08-01 11:28:25.793831+00	0.04	0	1906	1229	0	20	57	124	15	0	0	ok
1594	2026-08-01 11:29:25.795483+00	0.08	0	1906	1234	0	20	57	123	17	0	0	ok
1595	2026-08-01 11:30:25.795324+00	0.06	0	1906	1230	0	20	57	125	17	0	0	ok
1596	2026-08-01 11:31:25.795198+00	0.02	0	1906	1241	0	20	57	124	14	0	0	ok
1597	2026-08-01 11:32:41.763684+00	0.56	0	1906	1340	0	20	55	98	15	0	0	ok
1598	2026-08-01 11:33:41.747813+00	0.2	0	1906	1368	0	20	55	81	13	0	0	ok
1599	2026-08-01 11:34:41.747695+00	0.07	0	1906	1366	0	20	55	81	13	0	0	ok
1600	2026-08-01 11:35:41.748518+00	0.02	0	1906	1358	0	20	56	93	13	1	0	ok
1601	2026-08-01 11:36:41.750265+00	0.41	0	1906	1354	0	20	56	98	13	1	0	ok
1602	2026-08-01 11:37:41.750918+00	0.41	0	1906	1351	0	20	56	98	13	1	0	ok
1603	2026-08-01 11:38:41.75307+00	0.15	0	1906	1333	0	20	56	104	19	1	0	ok
1604	2026-08-01 11:39:41.75332+00	0.08	0	1906	1345	0	20	56	105	13	1	0	ok
1605	2026-08-01 11:40:41.758146+00	0.25	0	1906	1344	0	20	56	106	13	1	0	ok
1606	2026-08-01 11:41:41.752828+00	0.36	0	1906	1356	0	20	56	106	13	1	0	ok
1607	2026-08-01 11:42:25.483301+00	0.4	0	1906	1375	0	20	56	98	15	1	0	ok
1608	2026-08-01 11:43:25.483251+00	0.26	0	1906	1332	0	20	56	99	20	1	0	ok
1609	2026-08-01 11:44:25.486235+00	0.09	0	1906	1331	0	20	56	102	15	1	0	ok
1610	2026-08-01 11:45:25.483781+00	0.03	0	1906	1337	0	20	56	101	13	1	0	ok
1611	2026-08-01 11:46:25.483193+00	0.17	0	1906	1322	0	20	56	107	20	1	0	ok
1612	2026-08-01 11:47:25.483414+00	0.23	0	1906	1330	0	20	56	104	15	1	0	ok
1613	2026-08-01 11:48:25.483806+00	0.08	0	1906	1332	0	20	56	106	15	1	0	ok
1614	2026-08-01 11:49:25.483408+00	0.14	0	1906	1324	0	20	56	108	17	1	0	ok
1615	2026-08-01 11:50:25.488228+00	0.05	0	1906	1327	0	20	56	110	17	1	0	ok
1616	2026-08-01 11:51:25.482454+00	0.02	0	1906	1324	0	20	56	112	19	1	0	ok
1617	2026-08-01 11:52:25.483378+00	0	0	1906	1313	0	20	56	119	20	1	0	ok
1618	2026-08-01 11:53:25.485044+00	0.23	0	1906	1314	0	20	56	120	19	1	0	ok
1619	2026-08-01 11:54:25.483803+00	0.38	0	1906	1323	0	20	56	120	18	1	0	ok
1620	2026-08-01 11:55:25.503322+00	0.48	0	1906	1317	0	20	56	120	17	1	0	ok
1621	2026-08-01 11:56:25.486539+00	0.4	0	1906	1318	0	20	56	121	20	1	0	ok
1622	2026-08-01 11:57:25.485999+00	0.26	0	1906	1307	0	20	56	120	20	1	0	ok
1623	2026-08-01 11:58:25.488235+00	0.09	0	1906	1314	0	20	57	121	17	1	0	ok
1624	2026-08-01 11:59:25.485855+00	0.03	0	1906	1318	0	20	57	121	17	1	0	ok
1625	2026-08-01 12:00:25.485985+00	0.3	0	1906	1310	0	20	57	122	18	1	0	ok
1626	2026-08-01 12:01:25.487848+00	0.39	0	1906	1309	0	20	57	122	17	1	0	ok
1627	2026-08-01 12:02:25.488236+00	0.2	0	1906	1306	0	20	57	124	20	1	0	ok
1628	2026-08-01 12:03:25.491745+00	0.19	0	1906	1312	0	20	57	123	18	1	0	ok
1629	2026-08-01 12:04:25.489183+00	0.15	0	1906	1313	0	20	57	126	19	1	0	ok
1630	2026-08-01 12:05:25.48987+00	0.05	0	1906	1313	0	20	57	123	17	1	0	ok
1631	2026-08-01 12:06:25.490691+00	0.19	0	1906	1325	0	20	57	119	17	1	0	ok
1632	2026-08-01 12:07:25.493861+00	0.12	0	1906	1316	0	20	57	121	17	1	0	ok
1633	2026-08-01 12:08:25.493414+00	0.16	0	1906	1310	0	20	57	123	16	1	0	ok
1634	2026-08-01 12:09:25.495475+00	0.11	0.5	1906	1311	0	20	57	123	19	1	0	ok
1635	2026-08-01 12:10:25.494781+00	0.33	0	1906	1311	0	20	57	124	19	1	0	ok
1636	2026-08-01 12:11:25.501766+00	0.17	0	1906	1317	0	20	57	125	17	1	0	ok
1637	2026-08-01 12:12:25.496224+00	0.35	0	1906	1322	0	20	57	124	17	1	0	ok
1638	2026-08-01 12:13:25.496403+00	0.18	0	1906	1315	0	20	57	126	18	1	0	ok
1639	2026-08-01 12:14:25.497129+00	0.12	0	1906	1313	0	20	57	125	20	1	0	ok
1640	2026-08-01 12:15:25.499547+00	0.16	0	1906	1312	0	20	57	124	18	1	0	ok
1641	2026-08-01 12:16:25.500594+00	0.11	0.5	1906	1302	0	20	57	125	19	1	0	ok
1642	2026-08-01 12:17:25.498736+00	0.1	0	1906	1304	0	20	57	125	19	1	0	ok
1643	2026-08-01 12:18:25.497588+00	0.26	0	1906	1306	0	20	57	125	18	1	0	ok
1644	2026-08-01 12:19:25.498558+00	0.21	0.5	1906	1288	0	20	57	125	21	1	0	ok
1645	2026-08-01 12:20:25.500073+00	0.13	0	1906	1307	0	20	57	125	20	1	0	ok
1646	2026-08-01 12:21:25.497671+00	0.1	0	1906	1307	0	20	57	125	18	1	0	ok
1647	2026-08-01 12:22:25.498466+00	0.04	0	1906	1308	0	20	57	126	18	1	0	ok
1648	2026-08-01 12:23:25.500149+00	0.16	0	1906	1313	0	20	57	125	19	1	0	ok
1649	2026-08-01 12:24:25.501401+00	0.11	0	1906	1299	0	20	57	125	20	1	0	ok
1650	2026-08-01 12:25:25.499921+00	0.1	0.5	1906	1314	0	20	57	125	18	1	0	ok
1651	2026-08-01 12:26:25.503198+00	0.09	0	1906	1303	0	20	57	126	17	1	0	ok
1652	2026-08-01 12:27:25.502598+00	0.09	0	1906	1312	0	20	57	125	17	1	0	ok
1653	2026-08-01 12:28:25.502049+00	0.09	0	1906	1312	0	20	57	125	18	1	0	ok
1654	2026-08-01 12:29:25.502185+00	0.09	0	1906	1312	0	20	57	126	20	1	0	ok
1655	2026-08-01 12:30:25.502739+00	0.09	0	1906	1315	0	20	57	126	13	1	0	ok
1656	2026-08-01 12:31:25.504233+00	0.09	0	1906	1325	0	20	57	125	12	1	0	ok
1657	2026-08-01 12:32:25.505141+00	0.09	0	1906	1311	0	20	57	126	18	1	0	ok
1658	2026-08-01 12:33:25.505854+00	0.14	0	1906	1309	0	20	57	126	19	1	0	ok
1659	2026-08-01 12:34:25.505199+00	0.23	0	1906	1300	0	20	57	126	18	1	0	ok
1660	2026-08-01 12:35:25.507432+00	0.29	0	1906	1316	0	20	57	127	17	1	0	ok
1661	2026-08-01 12:36:25.507484+00	0.16	0	1906	1299	0	20	57	126	17	1	0	ok
1662	2026-08-01 12:37:25.507867+00	0.12	0	1906	1297	0	20	57	127	19	1	0	ok
1663	2026-08-01 12:38:25.508217+00	0.16	0	1906	1287	0	20	57	126	18	1	0	ok
1664	2026-08-01 12:39:25.507108+00	0.11	0	1906	1295	0	20	57	126	20	1	0	ok
1665	2026-08-01 12:40:25.509744+00	0.1	0	1906	1291	0	20	57	127	21	1	0	ok
1666	2026-08-01 12:41:25.509064+00	0.15	0	1906	1298	0	20	57	127	17	1	0	ok
1667	2026-08-01 12:42:25.509911+00	0.11	0	1906	1282	0	20	57	127	20	1	0	ok
1668	2026-08-01 12:43:25.509962+00	0.1	0	1906	1291	0	20	57	127	17	1	0	ok
1669	2026-08-01 12:44:25.510334+00	0.09	0	1906	1291	0	20	57	127	17	1	0	ok
1670	2026-08-01 12:45:25.509971+00	0.09	0	1906	1301	0	20	57	127	16	1	0	ok
1671	2026-08-01 12:46:25.508822+00	0.09	0	1906	1299	0	20	57	127	15	1	0	ok
1672	2026-08-01 12:47:25.520229+00	0.09	0	1906	1296	0	20	57	127	18	1	0	ok
1673	2026-08-01 12:48:25.510123+00	0.03	0	1906	1291	0	20	57	127	19	1	0	ok
1674	2026-08-01 12:49:25.509757+00	0.07	0	1906	1288	0	20	57	127	19	1	0	ok
1675	2026-08-01 12:50:25.50859+00	0.2	0	1906	1289	0	20	57	127	19	1	0	ok
1676	2026-08-01 12:51:25.509313+00	0.13	0	1906	1294	0	20	57	128	16	1	0	ok
1677	2026-08-01 12:52:25.509418+00	0.1	0	1906	1301	0	20	57	127	15	1	0	ok
1678	2026-08-01 12:53:25.508816+00	0.15	0	1906	1295	0	20	57	127	13	1	0	ok
1679	2026-08-01 12:54:25.510656+00	0.35	0	1906	1300	0	20	57	128	14	1	0	ok
1680	2026-08-01 12:55:25.511296+00	0.18	0	1906	1296	0	20	57	127	11	1	0	ok
1681	2026-08-01 12:56:25.508882+00	0.12	0.5	1906	1302	0	20	57	127	13	1	0	ok
1682	2026-08-01 12:56:27.257837+00	0.12	0	1906	1354	0	20	57	98	12	1	0	ok
1683	2026-08-01 12:57:27.25699+00	0.27	0	1906	1320	0	20	57	99	13	1	0	ok
1684	2026-08-01 12:58:27.256769+00	0.16	0	1906	1312	0	20	57	103	13	1	0	ok
1685	2026-08-01 12:59:27.256303+00	0.11	0	1906	1320	0	20	57	104	13	1	0	ok
1686	2026-08-01 13:00:27.258787+00	0.09	0	1906	1321	0	20	57	106	12	1	0	ok
1687	2026-08-01 13:01:27.257447+00	0.09	0.5	1906	1319	0	20	57	107	11	1	0	ok
1688	2026-08-01 13:02:27.259083+00	0.09	0	1906	1313	0	20	57	108	13	1	0	ok
1689	2026-08-01 13:03:27.258761+00	0.09	0	1906	1314	0	20	57	108	13	1	0	ok
1690	2026-08-01 13:04:27.259238+00	0.09	0	1906	1290	0	20	57	113	11	1	0	ok
1691	2026-08-01 13:05:27.259772+00	0.03	0	1906	1296	0	20	57	121	16	1	0	ok
1692	2026-08-01 13:06:27.261722+00	0.07	0	1906	1307	0	20	57	115	15	1	0	ok
1693	2026-08-01 13:07:27.261069+00	0.08	0	1906	1316	0	20	57	118	12	1	0	ok
1694	2026-08-01 13:08:27.26005+00	0.08	0	1906	1304	0	20	57	120	17	1	0	ok
1695	2026-08-01 13:09:27.260456+00	0.09	0	1906	1301	0	20	57	122	16	1	0	ok
1696	2026-08-01 13:10:27.260781+00	0.09	0	1906	1302	0	20	57	122	15	1	0	ok
1697	2026-08-01 13:11:27.262731+00	0.24	0	1906	1265	0	20	57	123	18	1	0	ok
1698	2026-08-01 13:12:27.264219+00	0.18	0	1906	1258	0	20	57	122	17	1	0	ok
1699	2026-08-01 13:13:27.263048+00	0.18	0	1906	1264	0	20	57	123	17	1	0	ok
1700	2026-08-01 13:14:27.262428+00	0.12	0	1906	1255	0	20	57	123	17	1	0	ok
1701	2026-08-01 13:15:27.262692+00	0.1	0	1906	1262	0	20	57	123	18	1	0	ok
1702	2026-08-01 13:16:27.262026+00	0.09	0	1906	1261	0	20	57	124	19	1	0	ok
1703	2026-08-01 13:17:27.265035+00	0.09	0.5	1906	1257	0	20	57	123	18	1	0	ok
1704	2026-08-01 13:18:27.2645+00	0.09	0	1906	1262	0	20	57	124	16	1	0	ok
1705	2026-08-01 13:19:27.265641+00	0.03	0	1906	1261	0	20	57	123	17	1	0	ok
1706	2026-08-01 13:20:27.265959+00	0.07	0	1906	1263	0	20	57	123	18	1	0	ok
1707	2026-08-01 13:21:27.273293+00	0.02	0	1906	1256	0	20	57	124	17	1	0	ok
1708	2026-08-01 13:22:27.268254+00	0.01	0	1906	1258	0	20	57	124	16	1	0	ok
1709	2026-08-01 13:23:27.267698+00	0	0	1906	1256	0	20	57	124	15	1	0	ok
1710	2026-08-01 13:24:27.270965+00	0	0.5	1906	1263	0	20	57	124	14	1	0	ok
1711	2026-08-01 13:25:27.270795+00	0.09	0	1906	1260	0	20	57	124	16	1	0	ok
1712	2026-08-01 13:26:27.270514+00	0.03	0	1906	1258	0	20	57	124	16	1	0	ok
1713	2026-08-01 13:27:27.270467+00	0.1	0	1906	1258	0	20	57	124	15	1	0	ok
1714	2026-08-01 13:28:27.271098+00	0.15	0	1906	1257	0	20	57	124	16	1	0	ok
1715	2026-08-01 13:29:27.271546+00	0.23	0	1906	1255	0	20	57	124	15	1	0	ok
1716	2026-08-01 13:30:27.272996+00	0.14	0	1906	1246	0	20	57	125	16	1	0	ok
1717	2026-08-01 13:31:27.272961+00	0.11	0	1906	1250	0	20	57	125	17	1	0	ok
1718	2026-08-01 13:32:27.271745+00	0.1	0	1906	1246	0	20	57	124	17	1	0	ok
1719	2026-08-01 13:33:27.272663+00	0.15	0	1906	1251	0	20	57	125	18	1	0	ok
1720	2026-08-01 13:34:27.272926+00	0.11	0	1906	1257	0	20	57	124	17	1	0	ok
1721	2026-08-01 13:35:27.274093+00	0.21	0	1906	1252	0	20	57	125	18	1	0	ok
1722	2026-08-01 13:36:27.273924+00	0.13	0	1906	1255	0	20	57	124	19	1	0	ok
1723	2026-08-01 13:37:27.274718+00	0.1	0	1906	1253	0	20	57	124	17	1	0	ok
1724	2026-08-01 13:38:27.275041+00	0.21	0	1906	1251	0	20	57	125	19	1	0	ok
1725	2026-08-01 13:38:52.431012+00	0.14	0	1906	1321	0	20	57	98	12	1	0	ok
1726	2026-08-01 13:39:52.429374+00	0.05	0	1906	1293	0	20	57	88	10	1	0	ok
1727	2026-08-01 13:40:52.42876+00	0.05	0	1906	1292	0	20	57	93	10	1	0	ok
1728	2026-08-01 13:41:52.426983+00	0.02	0	1906	1296	0	20	57	96	10	1	0	ok
1729	2026-08-01 13:41:58.231531+00	0.02	0	1906	1321	0	20	57	98	12	1	0	ok
1730	2026-08-01 13:42:58.230715+00	0.04	0	1906	1299	0	20	57	92	10	1	0	ok
1731	2026-08-01 13:43:58.233816+00	0.01	0	1906	1295	0	20	57	97	13	1	0	ok
1732	2026-08-01 13:44:18.273035+00	0.01	0	1906	1316	0	20	57	99	12	1	0	ok
1733	2026-08-01 13:45:18.273236+00	0.07	0	1906	1278	0	20	57	92	18	1	0	ok
1734	2026-08-01 13:46:18.272947+00	0.1	0	1906	1283	0	20	57	93	15	1	0	ok
1735	2026-08-01 13:47:18.270762+00	0.03	0	1906	1286	0	20	57	97	14	1	0	ok
1736	2026-08-01 13:48:18.276313+00	0.08	0	1906	1277	0	20	57	100	15	1	0	ok
1737	2026-08-01 13:49:18.277506+00	0.03	0	1906	1282	0	20	57	97	15	1	0	ok
1738	2026-08-01 13:50:18.275886+00	0.08	0	1906	1280	0	20	57	99	18	1	0	ok
1739	2026-08-01 13:51:18.278217+00	0.03	0	1906	1265	0	20	57	102	18	1	0	ok
1740	2026-08-01 13:51:31.127349+00	0.02	0	1906	1307	0	20	57	99	12	1	0	ok
1741	2026-08-01 13:52:31.128503+00	0.01	0	1906	1284	0	20	57	94	11	1	0	ok
1742	2026-08-01 13:53:31.129246+00	0	0	1906	1277	0	20	57	97	12	1	0	ok
1743	2026-08-01 13:54:31.131251+00	0.05	0	1906	1260	0	20	57	110	16	1	0	ok
1744	2026-08-01 13:55:31.130431+00	0.02	0	1906	1274	0	20	57	105	13	1	0	ok
1745	2026-08-01 13:56:31.129001+00	0	0	1906	1275	0	20	57	109	9	1	0	ok
1746	2026-08-01 13:57:31.129936+00	0	0	1906	1269	0	20	57	111	10	1	0	ok
1747	2026-08-01 13:58:31.130233+00	0	0	1906	1260	0	20	57	112	11	1	0	ok
1748	2026-08-01 13:59:31.130375+00	0.05	0	1906	1263	0	20	57	112	11	1	0	ok
1749	2026-08-01 14:00:31.133132+00	0.12	0.5	1906	1268	0	20	57	113	10	1	0	ok
1750	2026-08-01 14:01:31.135634+00	0.04	0	1906	1268	0	20	57	113	11	1	0	ok
1751	2026-08-01 14:02:31.135396+00	0.01	0.5	1906	1266	0	20	57	114	11	1	0	ok
1752	2026-08-01 14:03:32.509289+00	0	0	1906	1305	0	20	57	99	12	1	0	ok
1753	2026-08-01 14:04:32.510974+00	0.05	0	1906	1294	0	20	57	92	11	1	0	ok
1754	2026-08-01 14:05:32.508147+00	0.02	0	1906	1281	0	20	57	98	11	1	0	ok
1755	2026-08-01 14:06:32.507062+00	0.1	0	1906	1274	0	20	57	104	10	1	0	ok
1756	2026-08-01 14:07:32.508193+00	0.04	0	1906	1272	0	20	57	99	11	1	0	ok
1757	2026-08-01 14:08:32.508236+00	0.23	0	1906	1265	0	20	57	107	19	1	0	ok
1758	2026-08-01 14:09:32.508784+00	0.08	0	1906	1259	0	20	57	114	14	1	0	ok
1759	2026-08-01 14:10:32.510684+00	0.08	0	1906	1260	0	20	57	114	12	1	0	ok
1760	2026-08-01 14:11:32.515026+00	0.03	0	1906	1266	0	20	57	116	10	1	0	ok
1761	2026-08-01 14:12:32.509939+00	0.06	0	1906	1273	0	20	57	115	10	1	0	ok
1762	2026-08-01 14:13:32.509245+00	0.02	0	1906	1268	0	20	57	115	11	1	0	ok
1763	2026-08-01 14:14:32.509733+00	0.22	0	1906	1275	0	20	57	116	11	1	0	ok
1764	2026-08-01 14:15:32.50866+00	0.08	0	1906	1259	0	20	57	115	10	1	0	ok
1765	2026-08-01 14:16:32.513161+00	0.03	0	1906	1255	0	20	57	115	10	1	0	ok
1766	2026-08-01 14:17:32.510004+00	0.01	0	1906	1264	0	20	57	116	11	1	0	ok
1767	2026-08-01 14:17:47.202182+00	0.01	0	1906	1308	0	20	57	99	12	1	0	ok
1768	2026-08-01 14:18:47.201949+00	0.12	0	1906	1287	0	20	57	91	11	1	0	ok
1769	2026-08-01 14:19:47.202818+00	0.04	0	1906	1282	0	20	57	94	12	1	0	ok
1770	2026-08-01 14:20:47.203729+00	0.01	0	1906	1275	0	20	57	100	11	1	0	ok
1771	2026-08-01 14:21:47.203802+00	0	0	1906	1264	0	20	57	106	12	1	0	ok
1772	2026-08-01 14:22:47.203802+00	0.04	0	1906	1272	0	20	57	111	10	1	0	ok
1773	2026-08-01 14:23:47.204099+00	0.01	0	1906	1276	0	20	57	112	12	1	0	ok
1774	2026-08-01 14:24:47.204382+00	0	0	1906	1274	0	20	57	112	10	1	0	ok
1775	2026-08-01 14:25:47.204711+00	0	0	1906	1263	0	20	57	113	10	1	0	ok
1776	2026-08-01 14:26:47.203044+00	0	0	1906	1275	0	20	57	114	9	1	0	ok
1777	2026-08-01 14:27:38.187151+00	0	0	1906	1310	0	20	57	98	12	1	0	ok
1778	2026-08-01 14:27:49.928616+00	0	0	1906	1291	0	20	57	98	12	1	0	ok
1779	2026-08-01 14:28:49.924752+00	0	0	1906	1282	0	20	57	92	11	1	0	ok
1780	2026-08-01 14:29:49.925244+00	0	0	1906	1265	0	20	57	98	17	1	0	ok
1781	2026-08-01 14:30:49.927499+00	0.04	0	1906	1268	0	20	57	103	16	1	0	ok
1782	2026-08-01 14:31:49.929705+00	0.01	0	1906	1268	0	20	57	107	13	1	0	ok
1783	2026-08-01 14:32:49.930501+00	0	0	1906	1262	0	20	57	111	12	1	0	ok
1784	2026-08-01 14:33:49.930495+00	0	0	1906	1269	0	20	57	115	13	1	0	ok
1785	2026-08-01 14:34:49.933122+00	0.07	0	1906	1263	0	20	57	114	10	1	0	ok
1786	2026-08-01 14:35:49.930526+00	0.02	0	1906	1272	0	20	57	114	10	1	0	ok
1787	2026-08-01 14:36:49.932219+00	0.01	0	1906	1257	0	20	57	116	12	1	0	ok
1788	2026-08-01 14:37:49.931349+00	0.15	0	1906	1258	0	20	57	116	10	1	0	ok
1789	2026-08-01 14:38:43.06074+00	0.06	0	1906	1295	0	20	57	98	13	1	0	ok
1790	2026-08-01 14:39:43.062002+00	0.02	0	1906	1282	0	20	57	94	12	1	0	ok
1791	2026-08-01 14:40:43.062047+00	0.01	0	1906	1269	0	20	57	106	16	1	0	ok
1792	2026-08-01 14:41:43.062239+00	0	0	1906	1271	0	20	57	108	12	1	0	ok
1793	2026-08-01 14:42:43.06443+00	0	0	1906	1269	0	20	57	110	10	1	0	ok
1794	2026-08-01 14:43:00.230183+00	0	1	1906	1302	0	20	57	99	11	1	0	ok
1795	2026-08-01 14:44:00.231237+00	0	1	1906	1280	0	20	57	96	10	1	0	ok
1796	2026-08-01 14:45:00.228949+00	0	3.92	1906	1273	0	20	57	102	18	1	0	ok
1797	2026-08-01 14:46:00.222904+00	0	1.49	1906	1262	0	20	57	112	11	1	0	ok
1798	2026-08-01 14:47:00.225981+00	0	0	1906	1275	0	20	57	106	12	1	0	ok
1799	2026-08-01 14:48:00.225545+00	0	0	1906	1273	0	20	57	110	10	1	0	ok
1800	2026-08-01 14:55:46.382636+00	1.86	0.5	1906	1273	0	20	57	98	12	1	0	ok
1801	2026-08-01 14:56:46.385619+00	0.68	0	1906	1271	0	20	57	98	11	1	0	ok
1802	2026-08-01 14:57:46.384114+00	0.25	0	1906	1270	0	20	57	103	11	1	0	ok
1803	2026-08-01 14:58:46.384686+00	0.09	0	1906	1261	0	20	57	99	11	1	0	ok
1804	2026-08-01 14:59:46.383802+00	0.03	0	1906	1258	0	20	57	102	12	1	0	ok
1805	2026-08-01 15:00:46.38465+00	0.05	0	1906	1261	0	20	57	106	11	1	0	ok
1806	2026-08-01 15:01:46.385251+00	0.02	0	1906	1249	0	20	57	108	10	1	0	ok
1807	2026-08-01 15:02:46.38507+00	0	0	1906	1258	0	20	57	109	12	1	0	ok
1808	2026-08-01 15:03:46.385486+00	0	0	1906	1253	0	20	57	117	13	1	0	ok
1809	2026-08-01 15:04:46.386035+00	0	0	1906	1247	0	20	57	116	9	1	0	ok
1810	2026-08-01 15:05:46.386641+00	0	0	1906	1260	0	20	57	117	10	1	0	ok
1811	2026-08-01 15:06:46.387273+00	0	0	1906	1262	0	20	57	118	10	1	0	ok
1812	2026-08-01 15:07:46.394396+00	0	0	1906	1243	0	20	57	117	11	1	0	ok
1813	2026-08-01 15:08:46.389917+00	0	0	1906	1246	0	20	57	117	11	1	0	ok
1814	2026-08-01 15:09:46.388852+00	0	0	1906	1249	0	20	57	118	11	1	0	ok
1815	2026-08-01 15:10:46.387307+00	0.04	0	1906	1264	0	20	57	117	10	1	0	ok
1816	2026-08-01 15:11:46.38863+00	0.01	0	1906	1247	0	20	57	118	11	1	0	ok
1817	2026-08-01 15:12:46.387627+00	0	0	1906	1253	0	20	57	118	10	1	0	ok
1818	2026-08-01 15:13:46.389347+00	0	0	1906	1257	0	20	57	118	12	1	0	ok
1819	2026-08-01 15:14:46.391832+00	0	0	1906	1259	0	20	57	117	11	1	0	ok
1820	2026-08-01 15:15:46.389176+00	0	0	1906	1256	0	20	57	119	12	1	0	ok
1821	2026-08-01 15:16:46.389087+00	0	0	1906	1242	0	20	57	118	12	1	0	ok
1822	2026-08-01 15:17:46.389075+00	0	0	1906	1245	0	20	57	119	12	1	0	ok
1823	2026-08-01 15:18:46.390425+00	0	0	1906	1256	0	20	57	119	12	1	0	ok
1824	2026-08-01 15:19:46.390529+00	0	0	1906	1262	0	20	57	114	12	1	0	ok
1825	2026-08-01 15:20:46.389437+00	0	0	1906	1257	0	20	57	116	9	1	0	ok
1826	2026-08-01 15:21:03.961252+00	0	8.96	1906	1259	0	20	57	100	11	1	0	critical
1827	2026-08-01 15:22:02.84191+00	0.17	21.89	1906	1265	0	20	57	100	16	1	0	critical
1828	2026-08-01 15:23:02.877514+00	0.06	33	1906	1264	0	20	57	103	13	1	0	critical
1829	2026-08-01 15:24:02.899068+00	0.02	40.49	1906	1241	0	20	57	108	17	1	0	critical
1830	2026-08-01 15:25:02.925104+00	0.01	44.22	1906	1256	0	20	57	111	18	1	0	critical
1831	2026-08-01 15:26:02.891878+00	0	20.67	1906	1233	0	20	57	116	17	1	0	critical
1832	2026-08-01 15:27:02.902693+00	0	7.77	1906	1237	0	20	57	115	17	1	0	critical
1833	2026-08-01 15:28:02.902042+00	0	21.5	1906	1241	0	20	57	116	16	1	0	critical
1834	2026-08-01 15:29:02.912179+00	0	20.3	1906	1260	0	20	57	116	16	1	0	critical
1835	2026-08-01 15:30:03.043244+00	0.06	72.28	1906	1266	0	20	57	115	17	1	0	critical
1836	2026-08-01 15:31:02.979413+00	0.02	34.17	1906	1254	0	20	57	116	17	1	0	critical
1837	2026-08-01 15:32:02.977762+00	0.22	13.73	1906	1239	0	20	57	116	17	1	0	critical
1838	2026-08-01 15:33:02.98062+00	0.32	13.11	1906	1243	0	20	57	116	16	1	0	critical
1839	2026-08-01 15:34:02.985192+00	0.85	29.61	1906	1239	0	20	57	117	17	1	0	critical
1840	2026-08-01 15:34:40.331482+00	0.47	0	1906	1301	0	20	57	99	13	1	0	ok
1841	2026-08-01 15:35:39.28436+00	0.2	0	1906	1266	0	20	57	97	12	1	0	ok
1842	2026-08-01 15:36:39.288355+00	0.07	0	1906	1277	0	20	57	100	13	1	0	ok
1843	2026-08-01 15:37:39.286304+00	0.02	0	1906	1272	0	20	57	102	11	1	0	ok
1844	2026-08-01 15:38:39.287458+00	0.01	0	1906	1263	0	20	57	105	10	1	0	ok
1845	2026-08-01 15:39:39.289604+00	0	0	1906	1268	0	20	57	98	10	1	0	ok
1846	2026-08-01 15:40:39.288741+00	0	0	1906	1261	0	20	57	100	12	1	0	ok
1847	2026-08-01 15:41:39.290657+00	0	0	1906	1270	0	20	57	103	12	1	0	ok
1848	2026-08-01 15:42:39.294963+00	0	0	1906	1265	0	20	57	105	11	1	0	ok
1849	2026-08-01 15:43:39.293105+00	0	0	1906	1262	0	20	57	106	10	1	0	ok
1850	2026-08-01 15:44:39.292652+00	0	0	1906	1254	0	20	57	113	12	1	0	ok
1851	2026-08-01 15:45:39.291728+00	0	0	1906	1247	0	20	57	113	17	1	0	ok
1852	2026-08-01 15:46:39.293593+00	0	0	1906	1259	0	20	57	114	13	1	0	ok
1853	2026-08-01 15:47:39.291518+00	0	0	1906	1262	0	20	57	114	11	1	0	ok
1854	2026-08-01 15:48:39.291815+00	0	0	1906	1261	0	20	57	115	12	1	0	ok
1855	2026-08-01 15:49:39.292097+00	0	0	1906	1266	0	20	57	114	13	1	0	ok
1856	2026-08-01 15:50:39.292793+00	0	0	1906	1257	0	20	57	116	14	1	0	ok
1857	2026-08-01 15:51:39.292098+00	0	0	1906	1267	0	20	57	116	10	1	0	ok
1858	2026-08-01 15:52:39.293588+00	0.06	0	1906	1254	0	20	57	117	12	1	0	ok
1859	2026-08-01 15:52:44.655504+00	0.06	0.5	1906	1302	0	20	57	98	12	1	0	ok
1860	2026-08-01 15:53:44.655001+00	0.08	0	1906	1295	0	20	57	92	10	1	0	ok
1861	2026-08-01 15:54:44.654848+00	0.03	0	1906	1280	0	20	57	98	11	1	0	ok
1862	2026-08-01 15:55:44.653787+00	0.01	0	1906	1281	0	20	57	100	10	1	0	ok
1863	2026-08-01 15:56:25.516598+00	0	0.5	1906	1290	0	20	57	99	13	1	0	ok
1864	2026-08-01 15:57:25.514793+00	0.07	0	1906	1271	0	20	57	92	18	1	0	ok
1865	2026-08-01 15:58:25.514065+00	0.02	0	1906	1250	0	20	57	109	19	1	0	ok
1866	2026-08-01 15:59:25.51527+00	0.01	0	1906	1246	0	20	57	112	20	1	0	ok
1867	2026-08-01 16:00:25.515711+00	0.17	0	1906	1256	0	20	57	108	18	1	0	ok
1868	2026-08-01 16:01:25.515156+00	0.06	0.5	1906	1252	0	20	57	111	16	1	0	ok
1869	2026-08-01 16:02:25.515735+00	0.02	0	1906	1249	0	20	57	114	18	0	0	ok
1870	2026-08-01 16:03:25.514696+00	0.01	0	1906	1240	0	20	57	114	18	0	0	ok
1871	2026-08-01 16:04:25.516069+00	0	0	1906	1251	0	20	57	114	16	0	0	ok
1872	2026-08-01 16:05:25.515723+00	0	0	1906	1237	0	20	57	115	17	0	0	ok
1873	2026-08-01 16:06:25.516375+00	0	0	1906	1236	0	20	57	115	20	0	0	ok
1874	2026-08-01 16:07:25.517509+00	0	0.5	1906	1241	0	20	57	116	19	0	0	ok
1875	2026-08-01 16:08:25.520414+00	0	0	1906	1229	0	20	57	117	20	0	0	ok
1876	2026-08-01 16:09:25.518817+00	0.06	0	1906	1248	0	20	57	117	19	0	0	ok
1877	2026-08-01 16:10:25.51878+00	0.05	0	1906	1247	0	20	58	117	15	1	0	ok
1878	2026-08-01 16:11:25.519653+00	0.05	0	1906	1237	0	20	58	117	19	1	0	ok
1879	2026-08-01 16:12:25.52041+00	0.02	0	1906	1252	0	20	56	117	22	1	0	ok
1880	2026-08-01 16:13:25.526597+00	0	0	1906	1246	0	20	56	118	21	1	0	ok
1881	2026-08-01 16:14:25.520422+00	0	0	1906	1234	0	20	56	118	22	1	0	ok
1882	2026-08-01 16:15:25.518816+00	0	0	1906	1242	0	20	56	117	21	1	0	ok
1883	2026-08-01 16:16:25.520364+00	0	0	1906	1239	0	20	56	117	22	1	0	ok
1884	2026-08-01 16:17:25.519118+00	0	0	1906	1243	0	20	56	117	13	1	0	ok
1885	2026-08-01 16:18:25.519035+00	0	0	1906	1254	0	20	56	117	18	1	0	ok
1886	2026-08-01 16:19:25.518681+00	0	0	1906	1245	0	20	56	117	16	1	0	ok
1887	2026-08-01 16:20:25.519849+00	0	0	1906	1245	0	20	56	117	18	1	0	ok
1888	2026-08-01 16:21:25.520975+00	0	0	1906	1241	0	20	56	118	18	1	0	ok
1889	2026-08-01 16:22:25.52212+00	0	0	1906	1240	0	20	56	118	19	1	0	ok
1890	2026-08-01 16:23:25.522599+00	0	0	1906	1240	0	20	56	118	19	1	0	ok
1891	2026-08-01 16:24:25.522754+00	0	0	1906	1240	0	20	56	118	21	1	0	ok
1892	2026-08-01 16:25:25.522936+00	0	0	1906	1246	0	20	57	118	15	1	0	ok
1893	2026-08-01 16:26:25.522957+00	0	0	1906	1246	0	20	57	118	16	1	0	ok
1894	2026-08-01 16:27:25.524256+00	0	0	1906	1254	0	20	57	118	16	1	0	ok
1895	2026-08-01 16:28:25.525068+00	0	0	1906	1240	0	20	57	118	18	1	0	ok
1896	2026-08-01 16:29:25.523633+00	0	0	1906	1243	0	20	57	118	19	1	0	ok
1897	2026-08-01 16:30:25.524697+00	0	0	1906	1244	0	20	57	118	20	1	0	ok
1898	2026-08-01 16:31:25.526154+00	0	0	1906	1242	0	20	57	118	18	1	0	ok
1899	2026-08-01 16:32:25.523859+00	0	0	1906	1259	0	20	57	118	14	1	0	ok
1900	2026-08-01 16:33:25.526561+00	0	0	1906	1241	0	20	57	118	19	1	0	ok
1901	2026-08-01 16:34:25.526476+00	0	0	1906	1241	0	20	57	118	19	1	0	ok
1902	2026-08-01 16:35:25.526791+00	0.04	0	1906	1259	0	20	57	111	17	1	0	ok
1903	2026-08-01 16:36:25.527352+00	0.08	0	1906	1255	0	20	57	112	17	1	0	ok
1904	2026-08-01 16:37:25.528456+00	0.06	0	1906	1251	0	20	57	113	19	1	0	ok
1905	2026-08-01 16:38:25.53267+00	0.02	0	1906	1245	0	20	57	114	20	1	0	ok
1906	2026-08-01 16:39:25.528245+00	0.01	0	1906	1247	0	20	57	115	15	1	0	ok
1907	2026-08-01 16:40:25.527704+00	0	0	1906	1253	0	20	57	116	18	1	0	ok
1908	2026-08-01 16:41:25.526651+00	0	0	1906	1251	0	20	57	117	18	1	0	ok
1909	2026-08-01 16:42:25.529146+00	0.4	0	1906	1249	0	20	57	118	19	1	0	ok
1910	2026-08-01 16:43:25.528813+00	0.77	0	1906	1246	0	20	57	118	19	1	0	ok
1911	2026-08-01 16:44:25.529643+00	0.54	0	1906	1250	0	20	57	117	20	1	0	ok
1912	2026-08-01 16:45:25.530908+00	0.3	0	1906	1238	0	20	57	118	18	1	0	ok
1913	2026-08-01 16:46:25.528629+00	0.11	0	1906	1249	0	20	57	118	19	1	0	ok
1914	2026-08-01 16:47:25.530552+00	0.04	0	1906	1253	0	20	57	118	19	1	0	ok
1915	2026-08-01 16:48:25.532136+00	0.01	0	1906	1239	0	20	57	118	15	1	0	ok
1916	2026-08-01 16:49:25.533583+00	0	0	1906	1242	0	20	57	118	17	1	0	ok
1917	2026-08-01 16:50:25.53061+00	0	0	1906	1255	0	20	57	118	17	1	0	ok
1918	2026-08-01 16:51:25.530837+00	0	0	1906	1252	0	20	57	118	14	1	0	ok
1919	2026-08-01 16:52:25.530968+00	0	0	1906	1246	0	20	57	118	17	1	0	ok
1920	2026-08-01 16:53:25.532995+00	0	0	1906	1240	0	20	57	118	19	1	0	ok
1921	2026-08-01 16:54:25.532775+00	0	0	1906	1242	0	20	57	118	20	1	0	ok
1922	2026-08-01 16:55:25.532458+00	0	0	1906	1247	0	20	57	118	18	1	0	ok
1923	2026-08-01 16:56:25.536915+00	0	0	1906	1245	0	20	57	119	19	1	0	ok
1924	2026-08-01 16:57:25.54032+00	0	0	1906	1252	0	20	57	118	19	1	0	ok
1925	2026-08-01 16:58:25.534175+00	0	0	1906	1232	0	20	57	118	20	1	0	ok
1926	2026-08-01 16:59:25.534798+00	0.03	0	1906	1248	0	20	57	119	18	1	0	ok
1927	2026-08-01 17:00:25.535152+00	0.01	0	1906	1248	0	20	57	119	16	1	0	ok
1928	2026-08-01 17:01:25.535469+00	0	0	1906	1245	0	20	57	118	18	1	0	ok
1929	2026-08-01 17:02:25.534232+00	0.34	0	1906	1240	0	20	57	118	19	1	0	ok
1930	2026-08-01 17:03:25.537067+00	0.12	0	1906	1245	0	20	57	119	19	1	0	ok
1931	2026-08-01 17:04:25.540291+00	0.04	0	1906	1250	0	20	57	119	20	1	0	ok
1932	2026-08-01 17:05:25.538705+00	0.01	0	1906	1242	0	20	57	118	18	1	0	ok
1933	2026-08-01 17:06:25.54224+00	0	0	1906	1246	0	20	57	119	17	1	0	ok
1934	2026-08-01 17:07:25.538146+00	0	0	1906	1245	0	20	57	119	18	1	0	ok
1935	2026-08-01 17:08:25.538926+00	0	0	1906	1252	0	20	57	118	18	1	0	ok
1936	2026-08-01 17:09:25.538234+00	0	0	1906	1242	0	20	57	119	18	1	0	ok
1937	2026-08-01 17:10:25.541404+00	0.46	0	1906	1250	0	20	57	118	19	1	0	ok
1938	2026-08-01 17:11:25.541768+00	0.17	0	1906	1246	0	20	57	118	17	1	0	ok
1939	2026-08-01 17:12:25.541875+00	0.46	0	1906	1243	0	20	57	118	17	1	0	ok
1940	2026-08-01 17:13:25.540391+00	0.45	0	1906	1238	0	20	57	118	17	1	0	ok
1941	2026-08-01 17:14:25.542417+00	0.16	0	1906	1246	0	20	57	118	18	1	0	ok
1942	2026-08-01 17:15:25.542095+00	0.06	0	1906	1258	0	20	57	119	15	1	0	ok
1943	2026-08-01 17:16:25.542686+00	0.31	0	1906	1247	0	20	57	119	18	1	0	ok
1944	2026-08-01 17:17:25.544656+00	0.11	0	1906	1247	0	20	57	119	17	1	0	ok
1945	2026-08-01 17:18:25.545179+00	0.04	0	1906	1247	0	20	57	118	18	1	0	ok
1946	2026-08-01 17:19:25.546018+00	0.01	0	1906	1252	0	20	57	118	11	1	0	ok
1947	2026-08-01 17:20:25.546875+00	0	0	1906	1261	0	20	57	118	12	1	0	ok
1948	2026-08-01 17:21:25.545964+00	0	0	1906	1252	0	20	57	119	18	1	0	ok
1949	2026-08-01 17:22:25.547442+00	0	0	1906	1244	0	20	57	120	19	1	0	ok
1950	2026-08-01 17:23:25.54843+00	0.29	0	1906	1250	0	20	57	120	18	1	0	ok
1951	2026-08-01 17:24:25.548174+00	0.39	0	1906	1233	0	20	57	121	20	1	0	ok
1952	2026-08-01 17:25:25.548037+00	0.14	0	1906	1243	0	20	57	121	19	1	0	ok
1953	2026-08-01 17:26:25.547726+00	0.05	0	1906	1237	0	20	57	121	20	1	0	ok
1954	2026-08-01 17:27:25.551339+00	0.02	0	1906	1239	0	20	57	121	18	1	0	ok
1955	2026-08-01 17:28:25.548152+00	0.29	0	1906	1242	0	20	57	121	19	1	0	ok
1956	2026-08-01 17:29:25.549238+00	0.1	0	1906	1249	0	20	57	121	18	1	0	ok
1957	2026-08-01 17:30:25.550677+00	0.04	0	1906	1241	0	20	57	121	19	1	0	ok
1958	2026-08-01 17:31:25.550219+00	0.01	0	1906	1240	0	20	57	121	18	1	0	ok
1959	2026-08-01 17:32:25.550442+00	0.46	0	1906	1237	0	20	57	121	19	1	0	ok
1960	2026-08-01 17:33:25.555247+00	0.17	0	1906	1235	0	20	57	121	18	1	0	ok
1961	2026-08-01 17:34:25.554192+00	0.06	0	1906	1231	0	20	57	121	19	1	0	ok
1962	2026-08-01 17:35:25.555269+00	0.06	0	1906	1238	0	20	57	121	18	1	0	ok
1963	2026-08-01 17:36:25.554465+00	0.07	0	1906	1238	0	20	57	121	19	1	0	ok
1964	2026-08-01 17:37:25.556497+00	0.02	0	1906	1237	0	20	57	121	18	1	0	ok
1965	2026-08-01 17:38:25.557358+00	0.06	0	1906	1246	0	20	57	121	19	1	0	ok
1966	2026-08-01 17:39:25.557966+00	0.31	0	1906	1248	0	20	57	121	17	1	0	ok
1967	2026-08-01 17:40:25.557633+00	0.45	0	1906	1241	0	20	57	121	19	1	0	ok
1968	2026-08-01 17:41:25.557687+00	0.45	0	1906	1237	0	20	57	121	16	1	0	ok
1969	2026-08-01 17:42:25.55698+00	0.45	0	1906	1244	0	20	57	121	17	1	0	ok
1970	2026-08-01 17:43:25.558096+00	0.16	0	1906	1241	0	20	57	121	18	1	0	ok
1971	2026-08-01 17:44:25.559077+00	0.35	0	1906	1247	0	20	57	121	18	1	0	ok
1972	2026-08-01 17:45:25.556904+00	0.24	0	1906	1249	0	20	57	121	18	1	0	ok
1973	2026-08-01 17:46:25.557992+00	0.09	0	1906	1247	0	20	57	121	19	1	0	ok
1974	2026-08-01 17:47:25.556464+00	0.43	0	1906	1250	0	20	57	121	18	1	0	ok
1975	2026-08-01 17:48:25.557605+00	0.16	0	1906	1245	0	20	57	121	20	1	0	ok
1976	2026-08-01 17:49:25.557337+00	0.06	0	1906	1244	0	20	57	121	16	1	0	ok
1977	2026-08-01 17:50:25.557685+00	0.02	0	1906	1248	0	20	57	121	17	1	0	ok
1978	2026-08-01 17:51:25.558484+00	0	0	1906	1253	0	20	57	122	14	1	0	ok
1979	2026-08-01 17:52:25.555887+00	0	0	1906	1241	0	20	57	121	13	1	0	ok
1980	2026-08-01 17:53:25.55807+00	0.34	0	1906	1247	0	20	57	122	13	1	0	ok
1981	2026-08-01 17:54:25.557067+00	0.41	0	1906	1249	0	20	57	122	12	1	0	ok
1982	2026-08-01 17:55:25.557472+00	0.49	0	1906	1250	0	20	57	122	13	1	0	ok
1983	2026-08-01 17:56:25.557469+00	0.47	0	1906	1242	0	20	57	123	16	1	0	ok
1984	2026-08-01 17:57:25.557222+00	0.69	0	1906	1242	0	20	57	122	16	1	0	ok
1985	2026-08-01 17:58:25.557526+00	0.54	0	1906	1248	0	20	57	123	18	1	0	ok
1986	2026-08-01 17:59:25.557455+00	0.48	0	1906	1249	0	20	57	122	18	1	0	ok
1987	2026-08-01 18:00:25.557023+00	0.18	0.5	1906	1237	0	20	57	122	17	1	0	ok
1988	2026-08-01 18:01:25.556954+00	0.35	0	1906	1248	0	20	57	123	18	1	0	ok
1989	2026-08-01 18:02:25.558647+00	0.3	0	1906	1238	0	20	57	122	19	1	0	ok
1990	2026-08-01 18:03:25.560475+00	0.11	0	1906	1244	0	20	57	123	18	1	0	ok
1991	2026-08-01 18:04:25.558401+00	0.33	0	1906	1247	0	20	57	122	18	1	0	ok
1992	2026-08-01 18:05:25.557896+00	0.12	0	1906	1237	0	20	57	122	18	1	0	ok
1993	2026-08-01 18:06:25.55852+00	0.04	0	1906	1246	0	20	57	123	19	1	0	ok
1994	2026-08-01 18:07:25.558642+00	0.41	0	1906	1247	0	20	57	122	18	1	0	ok
1995	2026-08-01 18:08:25.558569+00	0.49	0	1906	1236	0	20	57	122	19	1	0	ok
1996	2026-08-01 18:09:25.559229+00	0.41	0	1906	1242	0	20	57	123	18	1	0	ok
1997	2026-08-01 18:10:25.563485+00	0.44	0	1906	1234	0	20	57	122	19	1	0	ok
1998	2026-08-01 18:11:25.561637+00	0.69	0	1906	1239	0	20	57	123	16	1	0	ok
1999	2026-08-01 18:12:25.563217+00	0.54	0	1906	1244	0	20	57	122	16	1	0	ok
2000	2026-08-01 18:13:25.561141+00	0.6	0	1906	1240	0	20	57	123	15	1	0	ok
2001	2026-08-01 18:14:25.561665+00	0.68	0	1906	1236	0	20	57	124	19	1	0	ok
2002	2026-08-01 18:15:25.560839+00	0.53	0	1906	1249	0	20	57	123	17	1	0	ok
2003	2026-08-01 18:16:25.561785+00	0.19	0	1906	1241	0	20	57	124	19	1	0	ok
2004	2026-08-01 18:17:25.56243+00	0.3	0	1906	1247	0	20	57	123	18	1	0	ok
2005	2026-08-01 18:18:25.561775+00	0.45	0	1906	1242	0	20	57	123	19	1	0	ok
2006	2026-08-01 18:19:25.563528+00	0.62	0	1906	1247	0	20	57	122	14	1	0	ok
2007	2026-08-01 18:20:25.564512+00	0.68	0	1906	1246	0	20	57	123	16	1	0	ok
2008	2026-08-01 18:21:25.564464+00	0.25	0	1906	1243	0	20	57	122	17	1	0	ok
2009	2026-08-01 18:22:25.563401+00	0.3	0	1906	1241	0	20	57	123	19	1	0	ok
2010	2026-08-01 18:23:25.565164+00	0.28	0	1906	1247	0	20	57	123	18	1	0	ok
2011	2026-08-01 18:24:25.56447+00	0.1	0	1906	1237	0	20	57	122	19	1	0	ok
2012	2026-08-01 18:25:25.566416+00	0.09	0	1906	1249	0	20	57	123	17	1	0	ok
2013	2026-08-01 18:26:25.566544+00	0.03	0	1906	1231	0	20	57	123	17	1	0	ok
2014	2026-08-01 18:27:25.565541+00	0.01	0	1906	1248	0	20	57	123	17	1	0	ok
2015	2026-08-01 18:28:25.565565+00	0.29	0	1906	1247	0	20	57	123	17	1	0	ok
2016	2026-08-01 18:29:25.565342+00	0.39	0	1906	1240	0	20	57	123	18	1	0	ok
2017	2026-08-01 18:30:25.566387+00	0.43	0	1906	1244	0	20	57	123	19	1	0	ok
2018	2026-08-01 18:31:25.56512+00	0.5	0	1906	1238	0	20	57	123	18	1	0	ok
2019	2026-08-01 18:32:25.565454+00	0.47	0	1906	1236	0	20	57	123	19	1	0	ok
2020	2026-08-01 18:33:25.565123+00	0.56	0	1906	1244	0	20	57	123	18	1	0	ok
2021	2026-08-01 18:34:25.566243+00	0.26	0	1906	1236	0	20	57	123	19	1	0	ok
2022	2026-08-01 18:35:25.565794+00	0.15	0	1906	1244	0	20	57	123	18	1	0	ok
2023	2026-08-01 18:36:25.566241+00	0.11	0	1906	1238	0	20	57	123	19	1	0	ok
2024	2026-08-01 18:37:25.56532+00	0.33	0	1906	1238	0	20	57	124	18	1	0	ok
2025	2026-08-01 18:38:25.565758+00	0.19	0	1906	1245	0	20	57	124	19	1	0	ok
2026	2026-08-01 18:39:25.565853+00	0.36	0	1906	1243	0	20	57	123	18	1	0	ok
2027	2026-08-01 18:40:25.566663+00	0.36	0	1906	1242	0	20	57	123	19	1	0	ok
2028	2026-08-01 18:41:25.565671+00	0.25	0	1906	1245	0	20	57	123	18	1	0	ok
2029	2026-08-01 18:42:25.566567+00	0.38	0	1906	1239	0	20	57	124	19	1	0	ok
2030	2026-08-01 18:43:25.570271+00	0.31	0	1906	1241	0	20	57	123	16	1	0	ok
2031	2026-08-01 18:44:25.56902+00	0.3	0	1906	1242	0	20	57	123	19	1	0	ok
2032	2026-08-01 18:45:25.571726+00	0.22	0	1906	1247	0	20	57	124	18	1	0	ok
2033	2026-08-01 18:46:25.568825+00	0.08	0	1906	1238	0	20	57	125	19	1	0	ok
2034	2026-08-01 18:47:25.568773+00	0.03	0	1906	1237	0	20	57	124	15	1	0	ok
2035	2026-08-01 18:48:25.568853+00	0.29	0	1906	1243	0	20	57	124	17	1	0	ok
2036	2026-08-01 18:49:25.569463+00	0.32	0	1906	1242	0	20	57	116	16	1	0	ok
2037	2026-08-01 18:50:25.568333+00	0.29	0	1906	1245	0	20	57	117	17	1	0	ok
2038	2026-08-01 18:51:25.569778+00	0.1	0	1906	1242	0	20	57	118	18	1	0	ok
2039	2026-08-01 18:52:25.572482+00	0.04	0	1906	1247	0	20	57	119	19	1	0	ok
2040	2026-08-01 18:53:25.570676+00	0.01	0	1906	1245	0	20	57	119	17	1	0	ok
2041	2026-08-01 18:54:25.569381+00	0	0	1906	1232	0	20	57	120	18	1	0	ok
2042	2026-08-01 18:55:25.570594+00	0	0	1906	1252	0	20	57	120	15	1	0	ok
2043	2026-08-01 18:56:25.570304+00	0	0	1906	1245	0	20	57	121	19	1	0	ok
2044	2026-08-01 18:57:25.572925+00	0	0.5	1906	1246	0	20	57	122	18	1	0	ok
2045	2026-08-01 18:58:25.573895+00	0	0	1906	1238	0	20	57	123	19	1	0	ok
2046	2026-08-01 18:59:25.573596+00	0	0	1906	1248	0	20	57	123	17	1	0	ok
2047	2026-08-01 19:00:25.573996+00	0	0	1906	1247	0	20	57	123	17	1	0	ok
2048	2026-08-01 19:01:25.573412+00	0.11	0	1906	1247	0	20	57	123	16	1	0	ok
2049	2026-08-01 19:02:25.575594+00	0.04	0	1906	1240	0	20	57	123	19	1	0	ok
2050	2026-08-01 19:03:25.573104+00	0.01	0	1906	1246	0	20	57	123	18	1	0	ok
2051	2026-08-01 19:04:25.574308+00	0.06	0.5	1906	1242	0	20	57	123	19	1	0	ok
2052	2026-08-01 19:05:25.573892+00	0.25	0	1906	1240	0	20	57	123	16	1	0	ok
2053	2026-08-01 19:06:25.574325+00	0.32	0	1906	1238	0	20	57	123	17	1	0	ok
2054	2026-08-01 19:07:25.575847+00	0.12	0	1906	1246	0	20	57	123	17	1	0	ok
2055	2026-08-01 19:08:25.574963+00	0.04	0	1906	1240	0	20	57	123	16	1	0	ok
2056	2026-08-01 19:09:25.57466+00	0.08	0	1906	1236	0	20	57	124	17	1	0	ok
2057	2026-08-01 19:10:25.573894+00	0.03	0	1906	1243	0	20	57	123	19	1	0	ok
2058	2026-08-01 19:11:25.575086+00	0.01	0	1906	1251	0	20	57	123	16	1	0	ok
2059	2026-08-01 19:12:25.573456+00	0	0	1906	1240	0	20	57	123	19	1	0	ok
2060	2026-08-01 19:13:25.576378+00	0	0	1906	1245	0	20	57	123	18	1	0	ok
2061	2026-08-01 19:14:25.574353+00	0.07	0.5	1906	1239	0	20	57	123	19	1	0	ok
2062	2026-08-01 19:15:25.575134+00	0.25	0	1906	1246	0	20	57	123	18	1	0	ok
2063	2026-08-01 19:16:25.575642+00	0.09	0	1906	1230	0	20	57	123	19	1	0	ok
2064	2026-08-01 19:17:25.575427+00	0.03	0	1906	1246	0	20	57	123	18	1	0	ok
2065	2026-08-01 19:18:25.576544+00	0.12	0	1906	1233	0	20	57	123	19	1	0	ok
2066	2026-08-01 19:19:25.575169+00	0.04	0	1906	1240	0	20	57	124	18	1	0	ok
2067	2026-08-01 19:20:25.575625+00	0.13	0	1906	1234	0	20	57	123	19	1	0	ok
2068	2026-08-01 19:21:25.578198+00	0.05	0	1906	1251	0	20	57	124	14	1	0	ok
2069	2026-08-01 19:22:25.575349+00	0.02	0	1906	1245	0	20	57	124	12	1	0	ok
2070	2026-08-01 19:23:25.574144+00	0	0	1906	1253	0	20	57	124	12	1	0	ok
2071	2026-08-01 19:24:25.576882+00	0	0	1906	1242	0	20	57	124	12	1	0	ok
2072	2026-08-01 19:25:25.575077+00	0	0	1906	1248	0	20	57	124	12	1	0	ok
2073	2026-08-01 19:26:25.575906+00	0	0.5	1906	1251	0	20	57	124	12	1	0	ok
2074	2026-08-01 19:27:25.579809+00	0	0	1906	1250	0	20	57	124	12	1	0	ok
2075	2026-08-01 19:28:25.579866+00	0	0	1906	1253	0	20	57	125	12	1	0	ok
2076	2026-08-01 19:29:25.578692+00	0	0	1906	1245	0	20	57	124	16	1	0	ok
2077	2026-08-01 19:30:25.581727+00	0.17	0	1906	1241	0	20	57	123	19	1	0	ok
2078	2026-08-01 19:31:25.58263+00	0.06	0	1906	1242	0	20	57	123	18	1	0	ok
2079	2026-08-01 19:32:25.583432+00	0.02	0	1906	1234	0	20	57	124	18	1	0	ok
2080	2026-08-01 19:33:25.581532+00	0.01	0	1906	1235	0	20	57	123	18	1	0	ok
2081	2026-08-01 19:34:25.584336+00	0	0	1906	1239	0	20	57	124	19	1	0	ok
2082	2026-08-01 19:35:25.583247+00	0	0	1906	1242	0	20	57	123	18	1	0	ok
2083	2026-08-01 19:36:25.586387+00	0	0.5	1906	1231	0	20	57	124	19	1	0	ok
2084	2026-08-01 19:37:25.587296+00	0	0	1906	1240	0	20	57	123	18	1	0	ok
2085	2026-08-01 19:38:25.585786+00	0	0	1906	1242	0	20	57	123	19	1	0	ok
2086	2026-08-01 19:39:25.586026+00	0.04	0	1906	1234	0	20	57	123	18	1	0	ok
2087	2026-08-01 19:40:25.588259+00	0.11	0	1906	1238	0	20	57	124	19	1	0	ok
2088	2026-08-01 19:41:25.585222+00	0.04	0	1906	1232	0	20	57	123	18	1	0	ok
2089	2026-08-01 19:42:25.586187+00	0.01	0.5	1906	1235	0	20	57	123	19	1	0	ok
2090	2026-08-01 19:43:25.586364+00	0	0	1906	1239	0	20	57	123	18	1	0	ok
2091	2026-08-01 19:44:25.587363+00	0	0	1906	1241	0	20	57	124	19	1	0	ok
2092	2026-08-01 19:45:25.587631+00	0	0	1906	1237	0	20	57	123	18	1	0	ok
2093	2026-08-01 19:46:25.589707+00	0	0	1906	1239	0	20	57	124	19	1	0	ok
2094	2026-08-01 19:47:25.58936+00	0	0	1906	1234	0	20	57	124	18	1	0	ok
2095	2026-08-01 19:48:25.591338+00	0	0	1906	1237	0	20	57	123	19	1	0	ok
2096	2026-08-01 19:49:25.591076+00	0	0	1906	1247	0	20	57	123	18	1	0	ok
2097	2026-08-01 19:50:25.593676+00	0	0	1906	1235	0	20	57	123	19	1	0	ok
2098	2026-08-01 19:51:25.594332+00	0	0	1906	1234	0	20	57	123	18	1	0	ok
2099	2026-08-01 19:52:25.595178+00	0	0	1906	1235	0	20	57	124	19	1	0	ok
2100	2026-08-01 19:53:25.593618+00	0	0	1906	1239	0	20	57	123	18	1	0	ok
2101	2026-08-01 19:54:25.595642+00	0.03	0	1906	1233	0	20	57	123	19	1	0	ok
2102	2026-08-01 19:55:25.59663+00	0.05	0	1906	1240	0	20	57	123	18	1	0	ok
2103	2026-08-01 19:56:25.598742+00	0.02	0	1906	1243	0	20	57	123	19	1	0	ok
2104	2026-08-01 19:57:25.597827+00	0	0	1906	1239	0	20	57	123	18	1	0	ok
2105	2026-08-01 19:58:25.598069+00	0	0	1906	1236	0	20	57	124	19	1	0	ok
2106	2026-08-01 19:59:25.598384+00	0	0	1906	1237	0	20	57	123	18	1	0	ok
2107	2026-08-01 20:00:25.599681+00	0	0	1906	1239	0	20	57	124	19	1	0	ok
2108	2026-08-01 20:01:25.598955+00	0	0	1906	1240	0	20	57	124	18	1	0	ok
2109	2026-08-01 20:02:25.599188+00	0	0	1906	1235	0	20	57	124	19	1	0	ok
2110	2026-08-01 20:03:25.602733+00	0.06	0	1906	1230	0	20	57	123	18	1	0	ok
2111	2026-08-01 20:04:25.603272+00	0.02	0	1906	1245	0	20	57	123	15	1	0	ok
2112	2026-08-01 20:05:25.60244+00	0	0	1906	1243	0	20	57	123	15	1	0	ok
2113	2026-08-01 20:06:25.60195+00	0	0.5	1906	1245	0	20	57	125	17	1	0	ok
2114	2026-08-01 20:07:25.603669+00	0	0	1906	1239	0	20	57	124	15	1	0	ok
2115	2026-08-01 20:08:25.603129+00	0.04	0	1906	1242	0	20	57	124	18	1	0	ok
2116	2026-08-01 20:09:25.603446+00	0.05	0	1906	1237	0	20	57	124	18	1	0	ok
2117	2026-08-01 20:10:25.604526+00	0.06	0	1906	1238	0	20	57	123	19	1	0	ok
2118	2026-08-01 20:11:25.60583+00	0.02	0	1906	1238	0	20	57	123	18	1	0	ok
2119	2026-08-01 20:12:25.60532+00	0.09	0.5	1906	1241	0	20	57	123	17	1	0	ok
2120	2026-08-01 20:13:25.606878+00	0.03	0	1906	1240	0	20	57	124	18	1	0	ok
2121	2026-08-01 20:14:25.608858+00	0.01	0	1906	1236	0	20	57	124	17	1	0	ok
2122	2026-08-01 20:15:25.607579+00	0	0	1906	1244	0	20	57	123	18	1	0	ok
2123	2026-08-01 20:16:25.611545+00	0	0	1906	1235	0	20	57	124	19	1	0	ok
2124	2026-08-01 20:17:25.611043+00	0.04	0	1906	1242	0	20	57	124	17	1	0	ok
2125	2026-08-01 20:18:25.609614+00	0.01	0	1906	1245	0	20	57	124	12	1	0	ok
2126	2026-08-01 20:19:25.613451+00	0	0	1906	1237	0	20	57	124	18	1	0	ok
2127	2026-08-01 20:20:25.612884+00	0	0	1906	1243	0	20	57	124	19	1	0	ok
2128	2026-08-01 20:21:25.612745+00	0	0	1906	1250	0	20	57	124	12	1	0	ok
2129	2026-08-01 20:22:25.613796+00	0	0.51	1906	1244	0	20	57	124	12	1	0	ok
2130	2026-08-01 20:23:25.612705+00	0	0	1906	1241	0	20	57	124	15	1	0	ok
2131	2026-08-01 20:24:25.614321+00	0	0	1906	1241	0	20	57	124	12	1	0	ok
2132	2026-08-01 20:25:25.614702+00	0	0	1906	1238	0	20	57	124	14	1	0	ok
2133	2026-08-01 20:26:25.613696+00	0	0.5	1906	1238	0	20	57	124	15	1	0	ok
2134	2026-08-01 20:27:25.614366+00	0	0.5	1906	1242	0	20	57	124	17	1	0	ok
2135	2026-08-01 20:28:25.615329+00	0	0	1906	1231	0	20	57	124	19	1	0	ok
2136	2026-08-01 20:29:25.616509+00	0	0	1906	1244	0	20	57	124	18	1	0	ok
2137	2026-08-01 20:30:25.615894+00	0	0	1906	1236	0	20	57	124	19	1	0	ok
2138	2026-08-01 20:31:25.616194+00	0	0	1906	1242	0	20	57	124	18	1	0	ok
2139	2026-08-01 20:32:25.615641+00	0	0	1906	1242	0	20	57	124	19	1	0	ok
2140	2026-08-01 20:33:25.618195+00	0	0	1906	1240	0	20	57	124	18	1	0	ok
2141	2026-08-01 20:34:25.619374+00	0	0	1906	1237	0	20	57	125	19	1	0	ok
2142	2026-08-01 20:35:25.618479+00	0	0	1906	1235	0	20	57	124	18	1	0	ok
2143	2026-08-01 20:36:25.618414+00	0	0	1906	1242	0	20	57	124	19	1	0	ok
2144	2026-08-01 20:37:25.618615+00	0	0	1906	1232	0	20	57	124	18	1	0	ok
2145	2026-08-01 20:38:25.619084+00	0	0	1906	1231	0	20	57	124	19	1	0	ok
2146	2026-08-01 20:39:25.617588+00	0	0	1906	1246	0	20	57	124	18	1	0	ok
2147	2026-08-01 20:40:25.617406+00	0	0	1906	1235	0	20	57	125	19	1	0	ok
2148	2026-08-01 20:41:25.617816+00	0	0	1906	1245	0	20	57	124	18	1	0	ok
2149	2026-08-01 20:42:25.617464+00	0	0	1906	1235	0	20	57	124	19	1	0	ok
2150	2026-08-01 20:43:25.618476+00	0.04	0	1906	1246	0	20	57	124	18	1	0	ok
2151	2026-08-01 20:44:25.61979+00	0.01	0	1906	1239	0	20	57	124	19	1	0	ok
2152	2026-08-01 20:45:25.618183+00	0	0	1906	1241	0	20	57	124	17	1	0	ok
2153	2026-08-01 20:46:25.618674+00	0	0	1906	1239	0	20	57	124	19	1	0	ok
2154	2026-08-01 20:47:25.621391+00	0.05	0	1906	1240	0	20	57	124	18	1	0	ok
2155	2026-08-01 20:48:25.620467+00	0.02	0	1906	1236	0	20	57	124	19	1	0	ok
2156	2026-08-01 20:49:25.622577+00	0	0	1906	1234	0	20	57	124	18	1	0	ok
2157	2026-08-01 20:50:25.622687+00	0	0	1906	1231	0	20	57	124	19	1	0	ok
2158	2026-08-01 20:51:25.622591+00	0.06	0	1906	1242	0	20	57	124	18	1	0	ok
2159	2026-08-01 20:52:25.626035+00	0.02	0	1906	1229	0	20	57	125	19	1	0	ok
2160	2026-08-01 20:53:25.625872+00	0.01	0	1906	1235	0	20	57	124	18	1	0	ok
2161	2026-08-01 20:54:25.628237+00	0.07	0	1906	1238	0	20	57	124	16	1	0	ok
2162	2026-08-01 20:55:25.629342+00	0.02	0	1906	1242	0	20	57	124	18	1	0	ok
2163	2026-08-01 20:56:25.629361+00	0.01	0	1906	1233	0	20	57	124	19	1	0	ok
2164	2026-08-01 20:57:25.628285+00	0	0	1906	1237	0	20	57	124	18	1	0	ok
2165	2026-08-01 20:58:25.628831+00	0	0	1906	1230	0	20	57	125	19	1	0	ok
2166	2026-08-01 20:59:25.629996+00	0	0	1906	1230	0	20	57	125	18	1	0	ok
2167	2026-08-01 21:00:25.629768+00	0	0	1906	1239	0	20	57	124	19	1	0	ok
2168	2026-08-01 21:01:25.62953+00	0	0	1906	1245	0	20	57	124	18	1	0	ok
2169	2026-08-01 21:02:25.632672+00	0	0	1906	1234	0	20	57	124	17	1	0	ok
2170	2026-08-01 21:03:25.634487+00	0	0	1906	1236	0	20	57	124	18	1	0	ok
2171	2026-08-01 21:04:25.634404+00	0	0	1906	1241	0	20	57	125	19	1	0	ok
2172	2026-08-01 21:05:25.63497+00	0	0	1906	1241	0	20	57	124	18	1	0	ok
2173	2026-08-01 21:06:25.636762+00	0	0	1906	1233	0	20	57	124	19	1	0	ok
2174	2026-08-01 21:07:25.637716+00	0	0	1906	1229	0	20	57	124	18	1	0	ok
2175	2026-08-01 21:08:25.636602+00	0	0	1906	1229	0	20	57	124	19	1	0	ok
2176	2026-08-01 21:09:25.637762+00	0	0	1906	1243	0	20	57	124	18	1	0	ok
2177	2026-08-01 21:10:25.639134+00	0	0	1906	1239	0	20	57	124	19	1	0	ok
2178	2026-08-01 21:11:25.637432+00	0	0	1906	1241	0	20	57	124	18	1	0	ok
2179	2026-08-01 21:12:25.639388+00	0.04	0	1906	1236	0	20	57	125	19	1	0	ok
2180	2026-08-01 21:13:25.639482+00	0.01	0	1906	1234	0	20	57	124	18	1	0	ok
2181	2026-08-01 21:14:25.642074+00	0	0.5	1906	1239	0	20	57	125	19	1	0	ok
2182	2026-08-01 21:15:25.639492+00	0	0	1906	1245	0	20	57	124	16	1	0	ok
2183	2026-08-01 21:16:25.641591+00	0	0	1906	1242	0	20	57	125	16	1	0	ok
2184	2026-08-01 21:17:25.641526+00	0	0	1906	1240	0	20	57	124	17	1	0	ok
2185	2026-08-01 21:18:25.641283+00	0	0	1906	1230	0	20	57	125	19	1	0	ok
2186	2026-08-01 21:19:25.642221+00	0	0	1906	1236	0	20	57	124	18	1	0	ok
2187	2026-08-01 21:20:25.645194+00	0	0	1906	1234	0	20	57	124	19	1	0	ok
2188	2026-08-01 21:21:25.643111+00	0	0	1906	1245	0	20	57	124	18	1	0	ok
2189	2026-08-01 21:22:25.64648+00	0	0	1906	1233	0	20	57	124	16	1	0	ok
2190	2026-08-01 21:23:25.644523+00	0	0	1906	1243	0	20	57	124	18	1	0	ok
2191	2026-08-01 21:24:25.645497+00	0	0	1906	1241	0	20	57	124	17	1	0	ok
2192	2026-08-01 21:25:25.6447+00	0	0	1906	1238	0	20	57	124	17	1	0	ok
2193	2026-08-01 21:26:25.646763+00	0	0	1906	1236	0	20	57	125	19	1	0	ok
2194	2026-08-01 21:27:25.645447+00	0	0	1906	1245	0	20	57	125	16	1	0	ok
2195	2026-08-01 21:28:25.647353+00	0	0	1906	1232	0	20	57	125	19	1	0	ok
2196	2026-08-01 21:29:25.648738+00	0	0	1906	1232	0	20	57	125	18	1	0	ok
2197	2026-08-01 21:30:25.650271+00	0	0	1906	1240	0	20	57	124	19	1	0	ok
2198	2026-08-01 21:31:25.6503+00	0	0	1906	1239	0	20	57	124	13	1	0	ok
2199	2026-08-01 21:32:25.649049+00	0	0	1906	1234	0	20	57	126	18	1	0	ok
2200	2026-08-01 21:33:25.651761+00	0.06	0	1906	1235	0	20	57	125	18	1	0	ok
2201	2026-08-01 21:34:25.651305+00	0.02	0	1906	1234	0	20	57	124	19	1	0	ok
2202	2026-08-01 21:35:25.6511+00	0.01	0	1906	1232	0	20	57	125	16	1	0	ok
2203	2026-08-01 21:36:25.655145+00	0	0	1906	1240	0	20	57	124	19	1	0	ok
2204	2026-08-01 21:37:25.652617+00	0	0	1906	1240	0	20	57	124	18	1	0	ok
2205	2026-08-01 21:38:25.653437+00	0	0	1906	1238	0	20	57	124	19	1	0	ok
2206	2026-08-01 21:39:25.654113+00	0	0	1906	1240	0	20	57	124	18	1	0	ok
2207	2026-08-01 21:40:25.655862+00	0	0	1906	1235	0	20	57	124	18	1	0	ok
2208	2026-08-01 21:41:25.654917+00	0	0	1906	1234	0	20	57	125	18	1	0	ok
2209	2026-08-01 21:42:25.655412+00	0	0	1906	1240	0	20	57	125	19	1	0	ok
2210	2026-08-01 21:43:25.654491+00	0.03	0	1906	1236	0	20	57	125	18	1	0	ok
2211	2026-08-01 21:44:25.658494+00	0.01	0	1906	1237	0	20	57	125	17	1	0	ok
2212	2026-08-01 21:45:25.657169+00	0.06	0	1906	1238	0	20	57	125	16	1	0	ok
2213	2026-08-01 21:46:25.656802+00	0.02	0	1906	1238	0	20	57	126	16	1	0	ok
2214	2026-08-01 21:47:25.659636+00	0.01	0.5	1906	1230	0	20	57	125	18	1	0	ok
2215	2026-08-01 21:48:25.656563+00	0	0	1906	1229	0	20	57	125	19	1	0	ok
2216	2026-08-01 21:49:25.655757+00	0	0	1906	1236	0	20	57	125	18	1	0	ok
2217	2026-08-01 21:50:25.657849+00	0	0	1906	1236	0	20	57	125	16	1	0	ok
2218	2026-08-01 21:51:25.656505+00	0	0	1906	1233	0	20	57	125	18	1	0	ok
2219	2026-08-01 21:52:25.657636+00	0.24	0.5	1906	1233	0	20	57	126	19	1	0	ok
2220	2026-08-01 21:53:25.657632+00	0.17	0	1906	1238	0	20	57	125	18	1	0	ok
2221	2026-08-01 21:54:25.657259+00	0.06	0	1906	1236	0	20	57	125	19	1	0	ok
2222	2026-08-01 21:55:25.655821+00	0.02	0	1906	1241	0	20	57	125	18	1	0	ok
2223	2026-08-01 21:56:25.658101+00	0.01	0	1906	1238	0	20	57	125	19	1	0	ok
2224	2026-08-01 21:57:25.658715+00	0	0	1906	1234	0	20	57	125	17	1	0	ok
2225	2026-08-01 21:58:25.659878+00	0	0.5	1906	1237	0	20	57	125	19	1	0	ok
2226	2026-08-01 21:59:25.658748+00	0	0	1906	1231	0	20	57	125	18	1	0	ok
2227	2026-08-01 22:00:25.65978+00	0	0	1906	1231	0	20	57	125	19	1	0	ok
2228	2026-08-01 22:01:25.661365+00	0	0	1906	1247	0	20	57	125	15	1	0	ok
2229	2026-08-01 22:02:25.661519+00	0	0	1906	1238	0	20	57	125	19	1	0	ok
2230	2026-08-01 22:03:25.658598+00	0	0	1906	1244	0	20	57	125	18	1	0	ok
2231	2026-08-01 22:04:25.658063+00	0	0	1906	1243	0	20	57	124	19	1	0	ok
2232	2026-08-01 22:05:25.65754+00	0	0	1906	1241	0	20	57	126	18	1	0	ok
2233	2026-08-01 22:06:25.65911+00	0	0	1906	1235	0	20	57	125	19	1	0	ok
2234	2026-08-01 22:07:25.65907+00	0	0	1906	1232	0	20	57	125	18	1	0	ok
2235	2026-08-01 22:08:25.663192+00	0	0	1906	1234	0	20	57	125	19	1	0	ok
2236	2026-08-01 22:09:25.66132+00	0	0	1906	1240	0	20	57	125	18	1	0	ok
2237	2026-08-01 22:10:25.66438+00	0	0	1906	1251	0	20	57	125	19	1	0	ok
2238	2026-08-01 22:11:25.663447+00	0	0	1906	1247	0	20	57	125	16	1	0	ok
2239	2026-08-01 22:12:25.664241+00	0	0	1906	1239	0	20	57	125	19	1	0	ok
2240	2026-08-01 22:13:25.663722+00	0	0	1906	1242	0	20	57	125	18	1	0	ok
2241	2026-08-01 22:14:25.665562+00	0	0	1906	1236	0	20	57	125	19	1	0	ok
2242	2026-08-01 22:15:25.668235+00	0	0.5	1906	1234	0	20	57	125	18	1	0	ok
2243	2026-08-01 22:16:25.665025+00	0	0	1906	1236	0	20	57	125	19	1	0	ok
2244	2026-08-01 22:17:25.665575+00	0	0	1906	1243	0	20	57	125	18	1	0	ok
2245	2026-08-01 22:18:25.666108+00	0	0	1906	1233	0	20	57	125	19	1	0	ok
2246	2026-08-01 22:19:25.665298+00	0	0	1906	1239	0	20	57	124	18	1	0	ok
2247	2026-08-01 22:20:25.666898+00	0.16	0	1906	1236	0	20	57	125	19	1	0	ok
2248	2026-08-01 22:21:25.667866+00	0.09	0	1906	1232	0	20	57	125	18	1	0	ok
2249	2026-08-01 22:22:25.671898+00	0.03	0	1906	1234	0	20	57	126	19	1	0	ok
2250	2026-08-01 22:23:25.670833+00	0.01	0	1906	1231	0	20	57	125	18	1	0	ok
2251	2026-08-01 22:24:25.671609+00	0	0	1906	1233	0	20	57	125	19	1	0	ok
2252	2026-08-01 22:25:25.671132+00	0.22	0	1906	1240	0	20	57	125	18	1	0	ok
2253	2026-08-01 22:26:25.671201+00	0.08	0	1906	1225	0	20	57	125	19	1	0	ok
2254	2026-08-01 22:27:25.672839+00	0.03	0	1906	1232	0	20	57	125	18	1	0	ok
2255	2026-08-01 22:28:25.675598+00	0.01	0	1906	1235	0	20	57	125	19	1	0	ok
2256	2026-08-01 22:29:25.675161+00	0	0	1906	1235	0	20	57	125	18	1	0	ok
2257	2026-08-01 22:30:25.677485+00	0.16	0	1906	1236	0	20	57	125	19	1	0	ok
2258	2026-08-01 22:31:25.678028+00	0.06	0	1906	1243	0	20	57	125	18	1	0	ok
2259	2026-08-01 22:32:25.678169+00	0.1	0	1906	1240	0	20	57	125	19	1	0	ok
2260	2026-08-01 22:33:25.678043+00	0.03	0	1906	1243	0	20	57	124	17	1	0	ok
2261	2026-08-01 22:34:25.68006+00	0.01	0	1906	1245	0	20	57	125	15	1	0	ok
2262	2026-08-01 22:35:25.681169+00	0	0	1906	1244	0	20	57	125	11	1	0	ok
2263	2026-08-01 22:36:25.681661+00	0	0	1906	1234	0	20	57	125	18	1	0	ok
2264	2026-08-01 22:37:25.681981+00	0	0	1906	1248	0	20	57	125	14	1	0	ok
2265	2026-08-01 22:38:25.680247+00	0	0	1906	1236	0	20	57	125	17	1	0	ok
2266	2026-08-01 22:39:25.680597+00	0	0	1906	1240	0	20	57	125	16	1	0	ok
2267	2026-08-01 22:40:25.680884+00	0	0	1906	1240	0	20	57	125	19	1	0	ok
2268	2026-08-01 22:41:25.683015+00	0	0	1906	1244	0	20	57	125	18	1	0	ok
2269	2026-08-01 22:42:25.683533+00	0.14	0	1906	1241	0	20	57	125	19	1	0	ok
2270	2026-08-01 22:43:25.682465+00	0.05	0.5	1906	1245	0	20	57	125	14	1	0	ok
2271	2026-08-01 22:44:25.68249+00	0.02	0	1906	1246	0	20	57	126	17	1	0	ok
2272	2026-08-01 22:45:25.682102+00	0	0	1906	1245	0	20	57	125	16	1	0	ok
2273	2026-08-01 22:46:25.683158+00	0	0	1906	1238	0	20	57	125	17	1	0	ok
2274	2026-08-01 22:47:25.686687+00	0	0	1906	1249	0	20	57	125	14	1	0	ok
2275	2026-08-01 22:48:25.686798+00	0	0	1906	1243	0	20	57	125	13	1	0	ok
2276	2026-08-01 22:49:25.687113+00	0	0	1906	1243	0	20	57	125	16	1	0	ok
2277	2026-08-01 22:50:25.68566+00	0.37	0	1906	1231	0	20	57	125	19	1	0	ok
2278	2026-08-01 22:51:25.686328+00	0.38	0	1906	1237	0	20	57	125	18	1	0	ok
2279	2026-08-01 22:52:25.687074+00	0.43	0	1906	1241	0	20	57	125	18	1	0	ok
2280	2026-08-01 22:53:25.686504+00	0.74	0	1906	1239	0	20	57	125	18	1	0	ok
2281	2026-08-01 22:54:25.687637+00	0.48	0	1906	1234	0	20	57	125	17	1	0	ok
2282	2026-08-01 22:55:25.688338+00	0.24	0	1906	1238	0	20	57	125	17	1	0	ok
2283	2026-08-01 22:56:25.686564+00	0.09	0	1906	1229	0	20	57	125	19	1	0	ok
2284	2026-08-01 22:57:25.688981+00	0.03	0	1906	1233	0	20	57	125	18	1	0	ok
2285	2026-08-01 22:58:25.690157+00	0.01	0	1906	1236	0	20	57	125	19	1	0	ok
2286	2026-08-01 22:59:25.688176+00	0	0	1906	1240	0	20	57	125	18	1	0	ok
2287	2026-08-01 23:00:25.689875+00	0.04	0	1906	1241	0	20	57	125	19	1	0	ok
2288	2026-08-01 23:01:25.689685+00	0.01	0	1906	1243	0	20	57	125	18	1	0	ok
2289	2026-08-01 23:02:25.689465+00	0	0.5	1906	1240	0	20	57	125	17	1	0	ok
2290	2026-08-01 23:03:25.689484+00	0	0	1906	1235	0	20	57	125	18	1	0	ok
2291	2026-08-01 23:04:25.69129+00	0	0	1906	1240	0	20	57	125	19	1	0	ok
2292	2026-08-01 23:05:25.688623+00	0	0.5	1906	1236	0	20	57	125	18	1	0	ok
2293	2026-08-01 23:06:25.691006+00	0	0	1906	1237	0	20	57	125	19	1	0	ok
2294	2026-08-01 23:07:25.68876+00	0	0.5	1906	1232	0	20	57	125	18	1	0	ok
2295	2026-08-01 23:08:25.68992+00	0	0	1906	1237	0	20	57	125	19	1	0	ok
2296	2026-08-01 23:09:25.694821+00	0	0	1906	1237	0	20	57	126	18	1	0	ok
2297	2026-08-01 23:10:25.691222+00	0.04	0	1906	1239	0	20	57	126	19	1	0	ok
2298	2026-08-01 23:11:25.691118+00	0.01	0	1906	1231	0	20	57	125	18	1	0	ok
2299	2026-08-01 23:12:25.693943+00	0	0	1906	1231	0	20	57	125	19	1	0	ok
2300	2026-08-01 23:13:25.693031+00	0	0	1906	1244	0	20	57	125	15	1	0	ok
2301	2026-08-01 23:14:25.694434+00	0	0	1906	1226	0	20	57	126	19	1	0	ok
2302	2026-08-01 23:15:25.693996+00	0.03	0	1906	1235	0	20	57	125	18	1	0	ok
2303	2026-08-01 23:16:25.695439+00	0.01	0	1906	1241	0	20	57	125	19	1	0	ok
2304	2026-08-01 23:17:25.695584+00	0	0	1906	1240	0	20	57	125	18	1	0	ok
2305	2026-08-01 23:18:25.698527+00	0.1	0	1906	1241	0	20	57	126	19	1	0	ok
2306	2026-08-01 23:19:25.696561+00	0.04	0	1906	1237	0	20	57	125	18	1	0	ok
2307	2026-08-01 23:20:25.700113+00	0.01	0	1906	1227	0	20	57	126	19	1	0	ok
2308	2026-08-01 23:21:25.701036+00	0.07	0	1906	1239	0	20	57	126	18	1	0	ok
2309	2026-08-01 23:22:25.700692+00	0.06	0	1906	1231	0	20	57	125	19	1	0	ok
2310	2026-08-01 23:23:25.703138+00	0.08	0	1906	1239	0	20	57	125	18	1	0	ok
2311	2026-08-01 23:24:25.703512+00	0.03	0	1906	1234	0	20	57	126	19	1	0	ok
2312	2026-08-01 23:25:25.703349+00	0.01	0	1906	1240	0	20	57	125	18	1	0	ok
2313	2026-08-01 23:26:25.704637+00	0	0	1906	1239	0	20	57	125	19	1	0	ok
2314	2026-08-01 23:27:25.704671+00	0	0	1906	1239	0	20	57	125	18	1	0	ok
2315	2026-08-01 23:28:25.705291+00	0	0	1906	1241	0	20	57	126	19	1	0	ok
2316	2026-08-01 23:29:25.706887+00	0.05	0	1906	1235	0	20	57	125	18	1	0	ok
2317	2026-08-01 23:30:25.70709+00	0.02	0	1906	1237	0	20	57	125	17	1	0	ok
2318	2026-08-01 23:31:25.70937+00	0	0	1906	1235	0	20	57	125	18	1	0	ok
2319	2026-08-01 23:32:25.710544+00	0.23	0	1906	1241	0	20	57	126	19	1	0	ok
2320	2026-08-01 23:33:25.708345+00	0.37	0	1906	1241	0	20	57	125	18	1	0	ok
2321	2026-08-01 23:34:25.707986+00	0.56	0	1906	1239	0	20	57	125	19	1	0	ok
2322	2026-08-01 23:35:25.709677+00	0.2	0.5	1906	1245	0	20	57	125	16	1	0	ok
2323	2026-08-01 23:36:25.710524+00	0.07	0	1906	1230	0	20	57	125	19	1	0	ok
2324	2026-08-01 23:37:25.712257+00	0.02	0	1906	1238	0	20	57	126	17	1	0	ok
2325	2026-08-01 23:38:25.711369+00	0.01	0	1906	1239	0	20	57	125	19	1	0	ok
2326	2026-08-01 23:39:25.714045+00	0	0	1906	1233	0	20	57	125	18	1	0	ok
2327	2026-08-01 23:40:25.715185+00	0	0	1906	1236	0	20	57	125	19	1	0	ok
2328	2026-08-01 23:41:25.716605+00	0	0	1906	1244	0	20	57	126	18	1	0	ok
2329	2026-08-01 23:42:25.717654+00	0	0	1906	1245	0	20	57	125	16	1	0	ok
2330	2026-08-01 23:43:25.716855+00	0	0	1906	1231	0	20	57	125	18	1	0	ok
2331	2026-08-01 23:44:25.716318+00	0	0	1906	1230	0	20	57	125	19	1	0	ok
2332	2026-08-01 23:45:25.721741+00	0	0	1906	1230	0	20	57	125	18	1	0	ok
2333	2026-08-01 23:46:25.720345+00	0	0	1906	1227	0	20	57	125	19	1	0	ok
2334	2026-08-01 23:47:25.720637+00	0	0	1906	1236	0	20	57	126	18	1	0	ok
2335	2026-08-01 23:48:25.720405+00	0	0	1906	1236	0	20	57	125	19	1	0	ok
2336	2026-08-01 23:49:25.72264+00	0	0	1906	1237	0	20	57	126	18	1	0	ok
2337	2026-08-01 23:50:25.721793+00	0	0	1906	1237	0	20	57	125	19	1	0	ok
2338	2026-08-01 23:51:25.723103+00	0	0	1906	1241	0	20	57	126	18	1	0	ok
2339	2026-08-01 23:52:25.723568+00	0	0.5	1906	1238	0	20	57	125	19	1	0	ok
2340	2026-08-01 23:53:25.725389+00	0	0	1906	1236	0	20	57	125	18	1	0	ok
2341	2026-08-01 23:54:25.726485+00	0	0	1906	1232	0	20	57	125	19	1	0	ok
2342	2026-08-01 23:55:25.725045+00	0	0	1906	1239	0	20	57	125	18	1	0	ok
2343	2026-08-01 23:56:25.725483+00	0	0	1906	1239	0	20	57	125	19	1	0	ok
2344	2026-08-01 23:57:25.72578+00	0	0	1906	1237	0	20	57	126	18	1	0	ok
2345	2026-08-01 23:58:25.726474+00	0	0	1906	1231	0	20	57	125	19	1	0	ok
2346	2026-08-01 23:59:25.727667+00	0	0	1906	1242	0	20	57	125	18	1	0	ok
2347	2026-08-02 00:00:25.72883+00	0.52	0	1906	1262	0	20	57	125	17	1	0	ok
2348	2026-08-02 00:01:25.727842+00	0.59	0	1906	1239	0	20	57	125	18	1	0	ok
2349	2026-08-02 00:02:25.727778+00	0.73	0	1906	1234	0	20	57	125	19	1	0	ok
2350	2026-08-02 00:03:25.728718+00	0.27	0	1906	1234	0	20	57	125	18	1	0	ok
2351	2026-08-02 00:04:25.728515+00	0.1	0	1906	1239	0	20	57	126	19	1	0	ok
2352	2026-08-02 00:05:25.729185+00	0.03	0	1906	1235	0	20	57	125	17	1	0	ok
2353	2026-08-02 00:06:25.728946+00	0.01	0.5	1906	1231	0	20	57	126	19	1	0	ok
2354	2026-08-02 00:07:25.731363+00	0	0	1906	1237	0	20	57	125	17	1	0	ok
2355	2026-08-02 00:08:25.732892+00	0	0	1906	1229	0	20	57	126	19	1	0	ok
2356	2026-08-02 00:09:25.731376+00	0.46	0.5	1906	1241	0	20	57	125	17	1	0	ok
2357	2026-08-02 00:10:25.73276+00	0.17	0	1906	1234	0	20	57	125	19	1	0	ok
2358	2026-08-02 00:11:25.732806+00	0.06	0	1906	1232	0	20	57	125	17	1	0	ok
2359	2026-08-02 00:12:25.732149+00	0.02	0	1906	1239	0	20	57	125	16	1	0	ok
2360	2026-08-02 00:13:25.735591+00	0.35	0	1906	1245	0	20	57	125	16	1	0	ok
2361	2026-08-02 00:14:25.735512+00	0.47	0	1906	1242	0	20	57	126	15	1	0	ok
2362	2026-08-02 00:15:25.737396+00	0.21	0	1906	1237	0	20	57	125	16	1	0	ok
2363	2026-08-02 00:16:25.73802+00	0.48	0	1906	1239	0	20	57	125	17	1	0	ok
2364	2026-08-02 00:17:25.738695+00	0.46	0	1906	1230	0	20	57	125	16	1	0	ok
2365	2026-08-02 00:18:25.739301+00	0.4	0	1906	1242	0	20	57	125	17	1	0	ok
2366	2026-08-02 00:19:25.738884+00	0.49	0	1906	1235	0	20	57	125	16	1	0	ok
2367	2026-08-02 00:20:25.739604+00	0.18	0	1906	1239	0	20	57	125	18	1	0	ok
2368	2026-08-02 00:21:25.741568+00	0.46	0	1906	1230	0	20	57	126	16	1	0	ok
2369	2026-08-02 00:22:25.742839+00	0.17	0	1906	1238	0	20	57	125	19	1	0	ok
2370	2026-08-02 00:23:25.744176+00	0.06	0	1906	1242	0	20	57	126	18	1	0	ok
2371	2026-08-02 00:24:25.744141+00	0.31	0	1906	1232	0	20	57	125	17	1	0	ok
2372	2026-08-02 00:25:25.745175+00	0.11	0	1906	1240	0	20	57	126	17	1	0	ok
2373	2026-08-02 00:26:25.745846+00	0.15	0	1906	1232	0	20	57	125	18	1	0	ok
2374	2026-08-02 00:27:25.746415+00	0.06	0	1906	1236	0	20	57	125	16	1	0	ok
2375	2026-08-02 00:28:25.745959+00	0.39	0	1906	1228	0	20	57	125	17	1	0	ok
2376	2026-08-02 00:29:25.749125+00	0.2	0	1906	1236	0	20	57	126	16	1	0	ok
2377	2026-08-02 00:30:25.748875+00	0.41	0	1906	1239	0	20	57	125	18	1	0	ok
2378	2026-08-02 00:31:25.74908+00	0.15	0	1906	1232	0	20	57	125	18	1	0	ok
2379	2026-08-02 00:32:25.752801+00	0.55	0	1906	1230	0	20	57	125	19	1	0	ok
2380	2026-08-02 00:33:25.748969+00	0.49	0	1906	1231	0	20	57	125	18	1	0	ok
2381	2026-08-02 00:34:25.755575+00	0.18	0	1906	1231	0	20	57	125	19	1	0	ok
2382	2026-08-02 00:35:25.751931+00	0.06	0	1906	1240	0	20	57	125	18	1	0	ok
2383	2026-08-02 00:36:25.754373+00	0.02	0	1906	1238	0	20	57	125	19	1	0	ok
2384	2026-08-02 00:37:25.753568+00	0.01	0	1906	1233	0	20	57	125	18	1	0	ok
2385	2026-08-02 00:38:25.75585+00	0.23	0	1906	1230	0	20	57	125	19	1	0	ok
2386	2026-08-02 00:39:25.755781+00	0.48	0	1906	1241	0	20	57	125	18	1	0	ok
2387	2026-08-02 00:40:25.757143+00	0.52	0	1906	1239	0	20	57	125	18	1	0	ok
2388	2026-08-02 00:41:25.757587+00	0.42	0	1906	1225	0	20	57	125	18	1	0	ok
2389	2026-08-02 00:42:25.757462+00	0.15	0	1906	1237	0	20	57	126	19	1	0	ok
2390	2026-08-02 00:43:25.758761+00	0.28	0	1906	1235	0	20	57	125	18	1	0	ok
2391	2026-08-02 00:44:25.757799+00	0.16	0	1906	1236	0	20	57	125	19	1	0	ok
2392	2026-08-02 00:45:25.760104+00	0.06	0	1906	1231	0	20	57	125	18	1	0	ok
2393	2026-08-02 00:46:25.758186+00	0.06	0	1906	1237	0	20	57	126	19	1	0	ok
2394	2026-08-02 00:47:25.76072+00	0.48	0	1906	1228	0	20	57	125	18	1	0	ok
2395	2026-08-02 00:48:25.760667+00	0.46	0.5	1906	1238	0	20	57	125	19	1	0	ok
2396	2026-08-02 00:49:25.760347+00	0.57	0	1906	1233	0	20	57	125	18	1	0	ok
2397	2026-08-02 00:50:25.760708+00	0.21	0	1906	1229	0	20	57	125	19	1	0	ok
2398	2026-08-02 00:51:25.760668+00	0.07	0.5	1906	1229	0	20	57	126	16	1	0	ok
2399	2026-08-02 00:52:25.762445+00	0.38	0	1906	1231	0	20	57	125	19	1	0	ok
2400	2026-08-02 00:53:25.762919+00	0.37	0	1906	1231	0	20	57	126	18	1	0	ok
2401	2026-08-02 00:54:25.763055+00	0.14	0	1906	1229	0	20	57	125	19	1	0	ok
2402	2026-08-02 00:55:25.762589+00	0.56	0	1906	1227	0	20	57	126	18	1	0	ok
2403	2026-08-02 00:56:25.763827+00	0.55	0	1906	1236	0	20	57	125	19	1	0	ok
2404	2026-08-02 00:57:25.765254+00	0.49	0	1906	1242	0	20	57	126	18	1	0	ok
2405	2026-08-02 00:58:25.764936+00	0.46	0	1906	1229	0	20	57	125	19	1	0	ok
2406	2026-08-02 00:59:25.767445+00	0.23	0	1906	1242	0	20	57	126	18	1	0	ok
2407	2026-08-02 01:00:25.769149+00	0.08	0.5	1906	1235	0	20	57	125	19	1	0	ok
2408	2026-08-02 01:01:25.770039+00	0.31	0	1906	1232	0	20	57	126	18	1	0	ok
2409	2026-08-02 01:02:25.770628+00	0.4	0.5	1906	1233	0	20	57	127	17	1	0	ok
2410	2026-08-02 01:03:25.77147+00	0.32	0	1906	1235	0	20	57	126	18	1	0	ok
2411	2026-08-02 01:04:25.770671+00	0.11	0	1906	1220	0	20	57	125	19	1	0	ok
2412	2026-08-02 01:05:25.773409+00	0.5	0	1906	1234	0	20	57	125	18	1	0	ok
2413	2026-08-02 01:06:25.77242+00	0.47	0	1906	1229	0	20	57	126	19	1	0	ok
2414	2026-08-02 01:07:25.772692+00	0.63	0.5	1906	1245	0	20	57	126	15	1	0	ok
2415	2026-08-02 01:08:25.771696+00	0.52	0	1906	1238	0	20	57	125	16	1	0	ok
2416	2026-08-02 01:09:25.774408+00	0.47	0	1906	1244	0	20	57	125	15	1	0	ok
2417	2026-08-02 01:10:25.774495+00	0.4	0	1906	1237	0	20	57	125	19	1	0	ok
2418	2026-08-02 01:11:25.776323+00	0.43	0	1906	1235	0	20	57	126	17	1	0	ok
2419	2026-08-02 01:12:25.77639+00	0.44	0	1906	1239	0	20	57	126	17	1	0	ok
2420	2026-08-02 01:13:25.776906+00	0.45	0	1906	1243	0	20	57	125	17	1	0	ok
2421	2026-08-02 01:14:25.777592+00	0.16	0	1906	1237	0	20	57	126	18	1	0	ok
2422	2026-08-02 01:15:25.776234+00	0.63	0	1906	1235	0	20	57	126	17	1	0	ok
2423	2026-08-02 01:16:25.775854+00	0.8	0	1906	1232	0	20	57	125	18	1	0	ok
2424	2026-08-02 01:17:25.776599+00	0.64	0	1906	1240	0	20	57	126	17	1	0	ok
2425	2026-08-02 01:18:25.777943+00	0.23	0	1906	1229	0	20	57	125	18	1	0	ok
2426	2026-08-02 01:19:25.778126+00	0.08	0	1906	1245	0	20	57	126	16	1	0	ok
2427	2026-08-02 01:20:25.777747+00	0.43	0	1906	1231	0	20	57	127	18	1	0	ok
2428	2026-08-02 01:21:25.777299+00	0.16	0	1906	1234	0	20	57	125	17	1	0	ok
2429	2026-08-02 01:22:25.778394+00	0.23	0	1906	1235	0	20	57	125	19	1	0	ok
2430	2026-08-02 01:23:25.778776+00	0.31	0	1906	1229	0	20	57	125	16	1	0	ok
2431	2026-08-02 01:24:25.781122+00	0.4	0	1906	1244	0	20	57	125	17	1	0	ok
2432	2026-08-02 01:25:25.779341+00	0.14	0	1906	1242	0	20	57	126	14	1	0	ok
2433	2026-08-02 01:26:25.779293+00	0.11	0	1906	1240	0	20	57	125	15	1	0	ok
2434	2026-08-02 01:27:25.782722+00	0.15	0	1906	1234	0	20	57	126	17	1	0	ok
2435	2026-08-02 01:28:25.779364+00	0.23	0	1906	1229	0	20	57	125	19	1	0	ok
2436	2026-08-02 01:29:25.780854+00	0.08	0	1906	1233	0	20	57	125	18	1	0	ok
2437	2026-08-02 01:30:25.780766+00	0.43	0	1906	1243	0	20	57	125	17	1	0	ok
2438	2026-08-02 01:31:25.780655+00	0.16	0	1906	1234	0	20	57	126	18	1	0	ok
2439	2026-08-02 01:32:25.779339+00	0.46	0	1906	1241	0	20	57	125	17	1	0	ok
2440	2026-08-02 01:33:25.780397+00	0.34	0	1906	1231	0	20	57	126	17	1	0	ok
2441	2026-08-02 01:34:25.780301+00	0.29	0	1906	1237	0	20	57	125	17	1	0	ok
2442	2026-08-02 01:35:25.779291+00	0.2	0	1906	1231	0	20	57	125	18	1	0	ok
2443	2026-08-02 01:36:25.779606+00	0.3	0	1906	1230	0	20	57	125	17	1	0	ok
2444	2026-08-02 01:37:25.782054+00	0.11	0	1906	1235	0	20	57	126	18	1	0	ok
2445	2026-08-02 01:38:25.780298+00	0.04	0	1906	1230	0	20	57	125	19	1	0	ok
2446	2026-08-02 01:39:25.781125+00	0.01	0	1906	1239	0	20	57	125	18	1	0	ok
2447	2026-08-02 01:40:25.783282+00	0.4	0	1906	1226	0	20	57	125	17	1	0	ok
2448	2026-08-02 01:41:25.781545+00	0.43	0	1906	1235	0	20	57	125	16	1	0	ok
2449	2026-08-02 01:42:25.782081+00	0.5	0	1906	1239	0	20	57	127	17	1	0	ok
2450	2026-08-02 01:43:25.7831+00	0.53	0	1906	1235	0	20	57	125	16	1	0	ok
2451	2026-08-02 01:44:25.783688+00	0.25	0	1906	1230	0	20	57	125	18	1	0	ok
2452	2026-08-02 01:45:25.784661+00	0.12	0	1906	1239	0	20	57	126	18	1	0	ok
2453	2026-08-02 01:46:25.782988+00	0.12	0	1906	1238	0	20	57	125	19	1	0	ok
2454	2026-08-02 01:47:25.784684+00	0.22	0	1906	1230	0	20	57	126	18	1	0	ok
2455	2026-08-02 01:48:25.784599+00	0.08	0	1906	1233	0	20	57	126	19	1	0	ok
2456	2026-08-02 01:49:25.785782+00	0.03	0	1906	1225	0	20	57	125	18	1	0	ok
2457	2026-08-02 01:50:25.786268+00	0.24	0	1906	1231	0	20	57	126	19	1	0	ok
2458	2026-08-02 01:51:25.785288+00	0.09	0	1906	1235	0	20	57	126	18	1	0	ok
2459	2026-08-02 01:52:25.786763+00	0.03	0	1906	1228	0	20	57	125	19	1	0	ok
2460	2026-08-02 01:53:25.787189+00	0.01	0	1906	1236	0	20	57	125	18	1	0	ok
2461	2026-08-02 01:54:25.785609+00	0	0	1906	1232	0	20	57	126	19	1	0	ok
2462	2026-08-02 01:55:25.787521+00	0.06	0	1906	1232	0	20	57	126	18	1	0	ok
2463	2026-08-02 01:56:25.788335+00	0.54	0	1906	1237	0	20	57	126	19	1	0	ok
2464	2026-08-02 01:57:25.786125+00	0.31	0.5	1906	1239	0	20	57	125	18	1	0	ok
2465	2026-08-02 01:58:25.786222+00	0.11	0	1906	1236	0	20	57	125	17	1	0	ok
2466	2026-08-02 01:59:25.788576+00	0.04	0	1906	1239	0	20	57	126	18	1	0	ok
2467	2026-08-02 02:00:25.789498+00	0.07	0	1906	1231	0	20	57	125	19	1	0	ok
2468	2026-08-02 02:01:25.790996+00	0.25	0	1906	1234	0	20	57	125	18	1	0	ok
2469	2026-08-02 02:02:25.791858+00	0.15	0	1906	1231	0	20	57	125	19	1	0	ok
2470	2026-08-02 02:03:25.791377+00	0.05	0	1906	1231	0	20	57	125	18	1	0	ok
2471	2026-08-02 02:04:25.791031+00	0.12	0	1906	1230	0	20	57	126	19	1	0	ok
2472	2026-08-02 02:05:25.792927+00	0.04	0	1906	1239	0	20	57	126	18	1	0	ok
2473	2026-08-02 02:06:25.794482+00	0.3	0	1906	1239	0	20	57	125	19	1	0	ok
2474	2026-08-02 02:07:25.79314+00	0.15	0	1906	1234	0	20	57	126	18	1	0	ok
2475	2026-08-02 02:08:25.794806+00	0.05	0	1906	1230	0	20	57	127	19	1	0	ok
2476	2026-08-02 02:09:25.79552+00	0.02	0	1906	1241	0	20	57	125	18	1	0	ok
2477	2026-08-02 02:10:25.794741+00	0.23	0	1906	1236	0	20	57	125	19	1	0	ok
2478	2026-08-02 02:11:25.795459+00	0.08	0	1906	1242	0	20	57	126	18	1	0	ok
2479	2026-08-02 02:12:25.79511+00	0.03	0	1906	1233	0	20	57	125	19	1	0	ok
2480	2026-08-02 02:13:25.795145+00	0.01	0	1906	1233	0	20	57	126	18	1	0	ok
2481	2026-08-02 02:14:25.796622+00	0	0	1906	1239	0	20	57	126	19	1	0	ok
2482	2026-08-02 02:15:25.795759+00	0	0	1906	1241	0	20	57	125	18	1	0	ok
2483	2026-08-02 02:16:25.796086+00	0	0	1906	1238	0	20	57	126	19	1	0	ok
2484	2026-08-02 02:17:25.798916+00	0.11	0	1906	1223	0	20	57	126	18	1	0	ok
2485	2026-08-02 02:18:25.800589+00	0.04	0	1906	1239	0	20	57	126	19	1	0	ok
2486	2026-08-02 02:19:25.800265+00	0.05	0	1906	1243	0	20	57	126	18	1	0	ok
2487	2026-08-02 02:20:25.801334+00	0.07	0	1906	1233	0	20	57	126	19	1	0	ok
2488	2026-08-02 02:21:25.804473+00	0.02	0	1906	1235	0	20	57	126	18	1	0	ok
2489	2026-08-02 02:22:25.803812+00	0.01	0	1906	1233	0	20	57	126	19	1	0	ok
2490	2026-08-02 02:23:25.80299+00	0.07	0	1906	1229	0	20	57	126	18	1	0	ok
2491	2026-08-02 02:24:25.805084+00	0.03	0	1906	1225	0	20	57	125	19	1	0	ok
2492	2026-08-02 02:25:25.803363+00	0.08	0	1906	1235	0	20	57	126	18	1	0	ok
2493	2026-08-02 02:26:25.805681+00	0.03	0	1906	1231	0	20	57	125	19	1	0	ok
2494	2026-08-02 02:27:25.805739+00	0.01	0	1906	1233	0	20	57	125	18	1	0	ok
2495	2026-08-02 02:28:25.808312+00	0	0	1906	1236	0	20	57	125	18	1	0	ok
2496	2026-08-02 02:29:25.812073+00	0.06	0	1906	1235	0	20	57	125	17	1	0	ok
2497	2026-08-02 02:30:25.812479+00	0.31	0	1906	1240	0	20	57	126	13	1	0	ok
2498	2026-08-02 02:31:25.810982+00	0.29	0	1906	1227	0	20	57	125	17	1	0	ok
2499	2026-08-02 02:32:25.811446+00	0.1	0	1906	1232	0	20	57	126	17	1	0	ok
2500	2026-08-02 02:33:25.811589+00	0.04	0	1906	1235	0	20	57	126	17	1	0	ok
2501	2026-08-02 02:34:25.812152+00	0.01	0	1906	1233	0	20	57	126	17	1	0	ok
2502	2026-08-02 02:35:25.812082+00	0	0	1906	1234	0	20	57	125	17	1	0	ok
2503	2026-08-02 02:36:25.814193+00	0	0	1906	1234	0	20	57	126	19	1	0	ok
2504	2026-08-02 02:37:25.813094+00	0	0	1906	1232	0	20	57	125	18	1	0	ok
2505	2026-08-02 02:38:25.813314+00	0	0.5	1906	1235	0	20	57	125	19	1	0	ok
2506	2026-08-02 02:39:25.812047+00	0	0	1906	1232	0	20	57	126	18	1	0	ok
2507	2026-08-02 02:40:25.812624+00	0	0	1906	1229	0	20	57	126	18	1	0	ok
2508	2026-08-02 02:41:25.816768+00	0	0	1906	1225	0	20	57	126	17	1	0	ok
2509	2026-08-02 02:42:25.813644+00	0	0	1906	1231	0	20	57	126	18	1	0	ok
2510	2026-08-02 02:43:25.813553+00	0	0	1906	1235	0	20	57	125	16	1	0	ok
2511	2026-08-02 02:44:25.814185+00	0	0	1906	1225	0	20	57	126	18	1	0	ok
2512	2026-08-02 02:45:25.8133+00	0.11	0.5	1906	1234	0	20	57	125	16	1	0	ok
2513	2026-08-02 02:46:25.813134+00	0.04	0	1906	1228	0	20	57	126	19	1	0	ok
2514	2026-08-02 02:47:25.815126+00	0.01	0	1906	1241	0	20	57	126	17	1	0	ok
2515	2026-08-02 02:48:25.814539+00	0	0	1906	1229	0	20	57	126	19	1	0	ok
2516	2026-08-02 02:49:25.813176+00	0	0	1906	1229	0	20	57	125	17	1	0	ok
2517	2026-08-02 02:50:25.812323+00	0	0	1906	1229	0	20	57	125	19	1	0	ok
2518	2026-08-02 02:51:25.812933+00	0	0	1906	1236	0	20	57	125	18	1	0	ok
2519	2026-08-02 02:52:25.813487+00	0	0	1906	1229	0	20	57	126	19	1	0	ok
2520	2026-08-02 02:53:25.812628+00	0	0	1906	1239	0	20	57	126	18	1	0	ok
2521	2026-08-02 02:54:25.813617+00	0	0	1906	1229	0	20	57	126	19	1	0	ok
2522	2026-08-02 02:55:25.816752+00	0	0	1906	1234	0	20	57	125	18	1	0	ok
2523	2026-08-02 02:56:25.815026+00	0	0	1906	1241	0	20	57	126	17	1	0	ok
2524	2026-08-02 02:57:25.817316+00	0	0	1906	1241	0	20	57	125	18	1	0	ok
2525	2026-08-02 02:58:25.817789+00	0.04	0	1906	1235	0	20	57	125	19	1	0	ok
2526	2026-08-02 02:59:25.818109+00	0.01	0	1906	1242	0	20	57	125	18	1	0	ok
2527	2026-08-02 03:00:25.820404+00	0	0.5	1906	1232	0	20	57	126	19	1	0	ok
2528	2026-08-02 03:01:25.81859+00	0	0	1906	1241	0	20	57	126	18	1	0	ok
2529	2026-08-02 03:02:25.820442+00	0	0.5	1906	1233	0	20	57	125	19	1	0	ok
2530	2026-08-02 03:03:25.82058+00	0	0	1906	1230	0	20	57	126	18	1	0	ok
2531	2026-08-02 03:04:25.820044+00	0	0	1906	1236	0	20	57	126	19	1	0	ok
2532	2026-08-02 03:05:25.819937+00	0	0	1906	1239	0	20	57	126	18	1	0	ok
2533	2026-08-02 03:06:25.822485+00	0	0	1906	1248	0	20	57	126	12	1	0	ok
2534	2026-08-02 03:07:25.823671+00	0	0	1906	1231	0	20	57	126	18	1	0	ok
2535	2026-08-02 03:08:25.822589+00	0	0	1906	1233	0	20	57	126	19	1	0	ok
2536	2026-08-02 03:09:25.822952+00	0	0	1906	1238	0	20	57	126	18	1	0	ok
2537	2026-08-02 03:10:25.821733+00	0	0	1906	1238	0	20	57	126	19	1	0	ok
2538	2026-08-02 03:11:25.822383+00	0	0	1906	1238	0	20	57	125	17	1	0	ok
2539	2026-08-02 03:12:25.823005+00	0	0	1906	1228	0	20	57	126	19	1	0	ok
2540	2026-08-02 03:13:25.827566+00	0	0	1906	1239	0	20	57	125	18	1	0	ok
2541	2026-08-02 03:14:25.830581+00	0	0	1906	1230	0	20	57	126	19	1	0	ok
2542	2026-08-02 03:15:25.829067+00	0	0	1906	1241	0	20	57	126	18	1	0	ok
2543	2026-08-02 03:16:25.829536+00	0	0	1906	1237	0	20	57	126	19	1	0	ok
2544	2026-08-02 03:17:25.829654+00	0	0	1906	1229	0	20	57	126	18	1	0	ok
2545	2026-08-02 03:18:25.829061+00	0	0	1906	1223	0	20	57	126	19	1	0	ok
2546	2026-08-02 03:19:25.829152+00	0	0	1906	1232	0	20	57	126	18	1	0	ok
2547	2026-08-02 03:20:25.82928+00	0	0	1906	1233	0	20	57	126	19	1	0	ok
2548	2026-08-02 03:21:25.831172+00	0	0	1906	1235	0	20	57	125	18	1	0	ok
2549	2026-08-02 03:22:25.82967+00	0	0	1906	1233	0	20	57	126	19	1	0	ok
2550	2026-08-02 03:23:25.831439+00	0	0	1906	1232	0	20	57	125	18	1	0	ok
2551	2026-08-02 03:24:25.830705+00	0	0	1906	1239	0	20	57	126	19	1	0	ok
2552	2026-08-02 03:25:25.83113+00	0	0	1906	1236	0	20	57	126	18	1	0	ok
2553	2026-08-02 03:26:25.831457+00	0	0	1906	1229	0	20	57	126	19	1	0	ok
2554	2026-08-02 03:27:25.832192+00	0	0	1906	1224	0	20	57	126	18	1	0	ok
2555	2026-08-02 03:28:25.832811+00	0	0	1906	1237	0	20	57	126	19	1	0	ok
2556	2026-08-02 03:29:25.831297+00	0	0	1906	1232	0	20	57	126	18	1	0	ok
2557	2026-08-02 03:30:25.832967+00	0	0	1906	1226	0	20	57	125	19	1	0	ok
2558	2026-08-02 03:31:25.833368+00	0	0	1906	1238	0	20	57	126	18	1	0	ok
2559	2026-08-02 03:32:25.834268+00	0	0	1906	1234	0	20	57	126	19	1	0	ok
2560	2026-08-02 03:33:25.834148+00	0	0	1906	1241	0	20	57	126	18	1	0	ok
2561	2026-08-02 03:34:25.834182+00	0	0	1906	1240	0	20	57	125	19	1	0	ok
2562	2026-08-02 03:35:25.836408+00	0	0	1906	1239	0	20	57	126	18	1	0	ok
2563	2026-08-02 03:36:25.83627+00	0	0	1906	1232	0	20	57	126	19	1	0	ok
2564	2026-08-02 03:37:25.836115+00	0	0	1906	1239	0	20	57	125	18	1	0	ok
2565	2026-08-02 03:38:25.837076+00	0	0	1906	1230	0	20	57	126	19	1	0	ok
2566	2026-08-02 03:39:25.837069+00	0.03	0	1906	1240	0	20	57	126	17	1	0	ok
2567	2026-08-02 03:40:25.838413+00	0.01	0	1906	1235	0	20	57	126	19	1	0	ok
2568	2026-08-02 03:41:25.838702+00	0	0	1906	1230	0	20	57	125	18	1	0	ok
2569	2026-08-02 03:42:25.838701+00	0	0	1906	1239	0	20	57	126	19	1	0	ok
2570	2026-08-02 03:43:25.843684+00	0	0	1906	1226	0	20	57	125	18	1	0	ok
2571	2026-08-02 03:44:25.846344+00	0	0	1906	1227	0	20	57	125	19	1	0	ok
2572	2026-08-02 03:45:25.845186+00	0	0	1906	1243	0	20	57	126	16	1	0	ok
2573	2026-08-02 03:46:25.846039+00	0	0	1906	1228	0	20	57	126	16	1	0	ok
2574	2026-08-02 03:47:25.845703+00	0	0	1906	1240	0	20	57	125	17	1	0	ok
2575	2026-08-02 03:48:25.845524+00	0	0	1906	1239	0	20	57	126	18	1	0	ok
2576	2026-08-02 03:49:25.845532+00	0	0	1906	1242	0	20	57	126	16	1	0	ok
2577	2026-08-02 03:50:25.845623+00	0	0	1906	1239	0	20	57	126	17	1	0	ok
2578	2026-08-02 03:51:25.846562+00	0	0	1906	1236	0	20	57	125	17	1	0	ok
2579	2026-08-02 03:52:25.845519+00	0.05	0	1906	1234	0	20	57	125	17	1	0	ok
2580	2026-08-02 03:53:25.847525+00	0.02	0	1906	1239	0	20	57	126	18	1	0	ok
2581	2026-08-02 03:54:25.847336+00	0	0	1906	1233	0	20	57	126	18	1	0	ok
2582	2026-08-02 03:55:25.847348+00	0	0	1906	1242	0	20	57	126	17	1	0	ok
2583	2026-08-02 03:56:25.849244+00	0.08	0	1906	1226	0	20	57	126	19	1	0	ok
2584	2026-08-02 03:57:25.849089+00	0.18	0	1906	1222	0	20	57	126	18	1	0	ok
2585	2026-08-02 03:58:25.849936+00	0.06	0	1906	1223	0	20	57	126	19	1	0	ok
2586	2026-08-02 03:59:25.852825+00	0.02	0.5	1906	1235	0	20	57	126	16	1	0	ok
2587	2026-08-02 04:00:25.851595+00	0.01	0	1906	1226	0	20	57	126	17	1	0	ok
2588	2026-08-02 04:01:25.852195+00	0	0	1906	1221	0	20	57	126	18	1	0	ok
2589	2026-08-02 04:02:25.851578+00	0	0	1906	1224	0	20	57	126	19	1	0	ok
2590	2026-08-02 04:03:25.851779+00	0	0	1906	1230	0	20	57	125	18	1	0	ok
2591	2026-08-02 04:04:25.851385+00	0	0	1906	1231	0	20	57	126	18	1	0	ok
2592	2026-08-02 04:05:25.851508+00	0	0	1906	1228	0	20	57	125	18	1	0	ok
2593	2026-08-02 04:06:25.853278+00	0	0	1906	1229	0	20	57	127	19	1	0	ok
2594	2026-08-02 04:07:25.8529+00	0	0	1906	1227	0	20	57	126	15	1	0	ok
2595	2026-08-02 04:08:25.852855+00	0.08	0	1906	1241	0	20	57	126	14	1	0	ok
2596	2026-08-02 04:09:25.852961+00	0.03	0	1906	1239	0	20	57	126	14	1	0	ok
2597	2026-08-02 04:10:25.854627+00	0.04	0	1906	1236	0	20	57	126	14	1	0	ok
2598	2026-08-02 04:11:25.855873+00	0.01	0.5	1906	1236	0	20	57	126	17	1	0	ok
2599	2026-08-02 04:12:25.854891+00	0	0.49	1906	1223	0	20	57	126	19	1	0	ok
2600	2026-08-02 04:13:25.854121+00	0	0	1906	1223	0	20	57	126	18	1	0	ok
2601	2026-08-02 04:14:25.856893+00	0	0	1906	1225	0	20	57	125	19	1	0	ok
2602	2026-08-02 04:15:25.857299+00	0	0	1906	1230	0	20	57	126	18	1	0	ok
2603	2026-08-02 04:16:25.858142+00	0	0	1906	1237	0	20	57	126	19	1	0	ok
2604	2026-08-02 04:17:25.85734+00	0	0	1906	1231	0	20	57	126	18	1	0	ok
2605	2026-08-02 04:18:25.856549+00	0	0	1906	1236	0	20	57	126	19	1	0	ok
2606	2026-08-02 04:19:25.856942+00	0	0	1906	1238	0	20	57	125	18	1	0	ok
2607	2026-08-02 04:20:25.857067+00	0	0	1906	1233	0	20	57	126	19	1	0	ok
2608	2026-08-02 04:21:25.858436+00	0	0	1906	1229	0	20	57	126	18	1	0	ok
2609	2026-08-02 04:22:25.86014+00	0	0	1906	1224	0	20	57	126	19	1	0	ok
2610	2026-08-02 04:23:25.859672+00	0	0	1906	1237	0	20	57	126	18	1	0	ok
2611	2026-08-02 04:24:25.858149+00	0	0	1906	1230	0	20	57	127	19	1	0	ok
2612	2026-08-02 04:25:25.857608+00	0	0	1906	1236	0	20	57	126	18	1	0	ok
2613	2026-08-02 04:26:25.859141+00	0	0	1906	1220	0	20	57	126	19	1	0	ok
2614	2026-08-02 04:27:25.858619+00	0	0	1906	1226	0	20	57	126	18	1	0	ok
2615	2026-08-02 04:28:25.858793+00	0	0	1906	1229	0	20	57	126	19	1	0	ok
2616	2026-08-02 04:29:25.860494+00	0	0	1906	1240	0	20	57	127	18	1	0	ok
2617	2026-08-02 04:30:25.861383+00	0	0	1906	1225	0	20	57	126	19	1	0	ok
2618	2026-08-02 04:31:25.860533+00	0	0	1906	1234	0	20	57	126	18	1	0	ok
2619	2026-08-02 04:32:25.862493+00	0	0	1906	1231	0	20	57	126	19	1	0	ok
2620	2026-08-02 04:33:25.863273+00	0	0	1906	1224	0	20	57	127	18	1	0	ok
2621	2026-08-02 04:34:25.863864+00	0	0	1906	1226	0	20	57	126	18	1	0	ok
2622	2026-08-02 04:35:25.864174+00	0	0	1906	1232	0	20	57	126	18	1	0	ok
2623	2026-08-02 04:36:25.865752+00	0	0.5	1906	1235	0	20	57	126	19	1	0	ok
2624	2026-08-02 04:37:25.867622+00	0	0	1906	1238	0	20	57	126	18	1	0	ok
2625	2026-08-02 04:38:25.869402+00	0	0	1906	1231	0	20	57	126	19	1	0	ok
2626	2026-08-02 04:39:25.87007+00	0	0	1906	1233	0	20	57	126	18	1	0	ok
2627	2026-08-02 04:40:25.872222+00	0.04	0	1906	1225	0	20	57	126	19	1	0	ok
2628	2026-08-02 04:41:25.871491+00	0.01	0	1906	1229	0	20	57	126	18	1	0	ok
2629	2026-08-02 04:42:25.872628+00	0	0	1906	1225	0	20	57	126	19	1	0	ok
2630	2026-08-02 04:43:25.873976+00	0	0	1906	1234	0	20	57	127	18	1	0	ok
2631	2026-08-02 04:44:25.87441+00	0	0	1906	1229	0	20	57	127	19	1	0	ok
2632	2026-08-02 04:45:25.873444+00	0	0.5	1906	1230	0	20	57	127	18	1	0	ok
2633	2026-08-02 04:46:25.877114+00	0	0	1906	1236	0	20	57	118	19	1	0	ok
2634	2026-08-02 04:47:25.875482+00	0	0	1906	1236	0	20	57	118	18	1	0	ok
2635	2026-08-02 04:48:25.880121+00	0	0	1906	1241	0	20	57	119	19	1	0	ok
2636	2026-08-02 04:49:25.875406+00	0	0	1906	1234	0	20	57	120	18	1	0	ok
2637	2026-08-02 04:50:25.88666+00	0.09	0	1906	1239	0	20	57	120	19	1	0	ok
2638	2026-08-02 04:51:25.885605+00	0.03	0	1906	1242	0	20	57	122	18	1	0	ok
2639	2026-08-02 04:52:25.888379+00	0.05	0	1906	1236	0	20	57	123	19	1	0	ok
2640	2026-08-02 04:53:25.886799+00	0.02	0	1906	1230	0	20	57	123	18	1	0	ok
2641	2026-08-02 04:54:25.888897+00	0	0	1906	1240	0	20	57	123	19	1	0	ok
2642	2026-08-02 04:55:25.889011+00	0	0	1906	1231	0	20	57	124	17	1	0	ok
2643	2026-08-02 04:56:25.887881+00	0	0.5	1906	1237	0	20	57	124	19	1	0	ok
2644	2026-08-02 04:57:25.888341+00	0	0	1906	1241	0	20	57	125	18	1	0	ok
2645	2026-08-02 04:58:25.887182+00	0	0	1906	1238	0	20	57	125	19	1	0	ok
2646	2026-08-02 04:59:25.887223+00	0	0	1906	1235	0	20	57	124	18	1	0	ok
2647	2026-08-02 05:00:25.886775+00	0	0	1906	1230	0	20	57	125	19	1	0	ok
2648	2026-08-02 05:01:25.888227+00	0	0	1906	1236	0	20	57	124	18	1	0	ok
2649	2026-08-02 05:02:25.888637+00	0	0	1906	1230	0	20	57	125	19	1	0	ok
2650	2026-08-02 05:03:25.889425+00	0	0	1906	1231	0	20	57	124	18	1	0	ok
2651	2026-08-02 05:04:25.888135+00	0	0	1906	1224	0	20	57	125	19	1	0	ok
2652	2026-08-02 05:05:25.888963+00	0	0	1906	1231	0	20	57	124	18	1	0	ok
2653	2026-08-02 05:06:25.888362+00	0	0	1906	1228	0	20	57	124	19	1	0	ok
2654	2026-08-02 05:07:25.889036+00	0	0	1906	1239	0	20	57	125	18	1	0	ok
2655	2026-08-02 05:08:25.888148+00	0.32	0	1906	1230	0	20	57	125	19	1	0	ok
2656	2026-08-02 05:09:25.887852+00	0.15	0	1906	1231	0	20	57	125	18	1	0	ok
2657	2026-08-02 05:10:25.88879+00	0.1	0	1906	1232	0	20	57	126	19	1	0	ok
2658	2026-08-02 05:11:25.889431+00	0.04	0	1906	1233	0	20	57	124	18	1	0	ok
2659	2026-08-02 05:12:25.889407+00	0.05	0	1906	1225	0	20	57	124	19	1	0	ok
2660	2026-08-02 05:13:25.88985+00	0.02	0	1906	1233	0	20	57	124	18	1	0	ok
2661	2026-08-02 05:14:25.888532+00	0	0	1906	1237	0	20	57	125	19	1	0	ok
2662	2026-08-02 05:15:25.890339+00	0.04	0	1906	1237	0	20	57	125	18	1	0	ok
2663	2026-08-02 05:16:25.890976+00	0.01	0	1906	1236	0	20	57	125	16	1	0	ok
2664	2026-08-02 05:17:25.89111+00	0	0	1906	1232	0	20	57	124	15	1	0	ok
2665	2026-08-02 05:18:25.891643+00	0	0	1906	1237	0	20	57	125	19	1	0	ok
2666	2026-08-02 05:19:25.892227+00	0	0.5	1906	1231	0	20	57	125	18	1	0	ok
2667	2026-08-02 05:20:25.893123+00	0	0	1906	1233	0	20	57	125	19	1	0	ok
2668	2026-08-02 05:21:25.892292+00	0	0	1906	1231	0	20	57	125	18	1	0	ok
2669	2026-08-02 05:22:25.89471+00	0	0	1906	1234	0	20	57	125	19	1	0	ok
2670	2026-08-02 05:23:25.894139+00	0	0	1906	1238	0	20	57	125	18	1	0	ok
2671	2026-08-02 05:24:25.893674+00	0.1	0	1906	1224	0	20	57	125	19	1	0	ok
2672	2026-08-02 05:25:25.895079+00	0.08	0	1906	1239	0	20	57	125	18	1	0	ok
2673	2026-08-02 05:26:25.895727+00	0.5	0	1906	1238	0	20	57	125	18	1	0	ok
2674	2026-08-02 05:27:25.895768+00	0.39	0	1906	1224	0	20	57	125	17	1	0	ok
2675	2026-08-02 05:28:25.895515+00	0.3	0	1906	1234	0	20	57	125	12	1	0	ok
2676	2026-08-02 05:29:25.895285+00	0.37	0	1906	1234	0	20	57	125	15	1	0	ok
2677	2026-08-02 05:30:25.898255+00	0.17	0	1906	1232	0	20	57	125	16	1	0	ok
2678	2026-08-02 05:31:25.897281+00	0.06	0	1906	1235	0	20	57	124	16	1	0	ok
2679	2026-08-02 05:32:25.896559+00	0.02	0	1906	1234	0	20	57	125	16	1	0	ok
2680	2026-08-02 05:33:25.896288+00	0.01	0	1906	1232	0	20	57	125	16	1	0	ok
2681	2026-08-02 05:34:25.896384+00	0.04	0	1906	1234	0	20	57	125	17	1	0	ok
2682	2026-08-02 05:35:25.89759+00	0.01	0	1906	1237	0	20	57	125	16	1	0	ok
2683	2026-08-02 05:36:25.897555+00	0.1	0	1906	1241	0	20	57	125	17	1	0	ok
2684	2026-08-02 05:37:25.896983+00	0.04	0	1906	1231	0	20	57	125	16	1	0	ok
2685	2026-08-02 05:38:25.898963+00	0.01	0	1906	1233	0	20	57	125	19	1	0	ok
2686	2026-08-02 05:39:25.899112+00	0	0	1906	1239	0	20	57	125	18	1	0	ok
2687	2026-08-02 05:40:25.89932+00	0	0	1906	1229	0	20	57	125	17	1	0	ok
2688	2026-08-02 05:41:25.900639+00	0	0	1906	1238	0	20	57	125	16	1	0	ok
2689	2026-08-02 05:42:25.896967+00	0	0.5	1906	1238	0	20	57	125	16	1	0	ok
2690	2026-08-02 05:43:25.8996+00	0	0	1906	1243	0	20	57	125	16	1	0	ok
2691	2026-08-02 05:44:25.89987+00	0	0	1906	1238	0	20	57	124	17	1	0	ok
2692	2026-08-02 05:45:25.898886+00	0	0	1906	1231	0	20	57	125	16	1	0	ok
2693	2026-08-02 05:46:25.900105+00	0	0	1906	1241	0	20	57	125	17	1	0	ok
2694	2026-08-02 05:47:25.898538+00	0	0	1906	1233	0	20	57	125	17	1	0	ok
2695	2026-08-02 05:48:25.902847+00	0	0	1906	1232	0	20	57	125	19	1	0	ok
2696	2026-08-02 05:49:25.902913+00	0	0	1906	1238	0	20	57	125	18	1	0	ok
2697	2026-08-02 05:50:25.903457+00	0	0	1906	1229	0	20	57	125	19	1	0	ok
2698	2026-08-02 05:51:25.905628+00	0	0	1906	1230	0	20	57	126	18	1	0	ok
2699	2026-08-02 05:52:25.904498+00	0	0.5	1906	1235	0	20	57	125	19	1	0	ok
2700	2026-08-02 05:53:25.90633+00	0	0	1906	1231	0	20	57	125	17	1	0	ok
2701	2026-08-02 05:54:25.905525+00	0	0	1906	1234	0	20	57	125	19	1	0	ok
2702	2026-08-02 05:55:25.908533+00	0	0	1906	1231	0	20	57	124	18	1	0	ok
2703	2026-08-02 05:56:25.908238+00	0	0	1906	1238	0	20	57	125	19	1	0	ok
2704	2026-08-02 05:57:25.910394+00	0	0	1906	1232	0	20	57	125	18	1	0	ok
2705	2026-08-02 05:58:25.90843+00	0.06	0	1906	1224	0	20	57	125	19	1	0	ok
2706	2026-08-02 05:59:25.908682+00	0.02	0	1906	1235	0	20	57	125	18	1	0	ok
2707	2026-08-02 06:00:25.908864+00	0.04	0	1906	1234	0	20	57	125	19	1	0	ok
2708	2026-08-02 06:01:25.90857+00	0.01	0.5	1906	1242	0	20	57	125	16	1	0	ok
2709	2026-08-02 06:02:25.908547+00	0	0	1906	1239	0	20	57	125	19	1	0	ok
2710	2026-08-02 06:03:25.908487+00	0	0	1906	1236	0	20	57	125	18	1	0	ok
2711	2026-08-02 06:04:25.910475+00	0	0	1906	1230	0	20	57	125	19	1	0	ok
2712	2026-08-02 06:05:25.911335+00	0	0	1906	1231	0	20	57	125	18	1	0	ok
2713	2026-08-02 06:06:25.910162+00	0	0	1906	1237	0	20	57	126	19	1	0	ok
2714	2026-08-02 06:07:25.911878+00	0	0	1906	1232	0	20	57	125	18	1	0	ok
2715	2026-08-02 06:08:25.911682+00	0	0	1906	1229	0	20	57	125	19	1	0	ok
2716	2026-08-02 06:09:25.913525+00	0	0	1906	1231	0	20	57	125	18	1	0	ok
2717	2026-08-02 06:10:25.911537+00	0	0	1906	1239	0	20	57	125	17	1	0	ok
2718	2026-08-02 06:11:25.912853+00	0	0	1906	1238	0	20	57	125	16	1	0	ok
2719	2026-08-02 06:12:25.914243+00	0.53	0	1906	1240	0	20	57	125	19	1	0	ok
2720	2026-08-02 06:13:25.914842+00	0.36	0	1906	1232	0	20	57	125	15	1	0	ok
2721	2026-08-02 06:14:25.916437+00	0.29	0	1906	1235	0	20	57	125	15	1	0	ok
2722	2026-08-02 06:15:25.915057+00	0.1	0	1906	1231	0	20	57	125	15	1	0	ok
2723	2026-08-02 06:16:25.916424+00	0.04	0	1906	1235	0	20	57	125	16	1	0	ok
2724	2026-08-02 06:17:25.916894+00	0.01	0	1906	1239	0	20	57	125	15	1	0	ok
2725	2026-08-02 06:18:25.917113+00	0	0	1906	1230	0	20	57	125	19	1	0	ok
2726	2026-08-02 06:19:25.917476+00	0	0	1906	1238	0	20	57	125	18	1	0	ok
2727	2026-08-02 06:20:25.916981+00	0.04	0	1906	1234	0	20	57	125	19	1	0	ok
2728	2026-08-02 06:21:25.916841+00	0.01	0	1906	1228	0	20	57	125	18	1	0	ok
2729	2026-08-02 06:22:25.919599+00	0	0	1906	1223	0	20	57	125	19	1	0	ok
2730	2026-08-02 06:23:25.921101+00	0	0	1906	1233	0	20	57	125	18	1	0	ok
2731	2026-08-02 06:24:25.920761+00	0	0	1906	1234	0	20	57	126	19	1	0	ok
2732	2026-08-02 06:25:25.922175+00	0	0	1906	1236	0	20	57	125	18	1	0	ok
2733	2026-08-02 06:26:25.927162+00	0	0	1906	1234	0	20	57	126	19	1	0	ok
2734	2026-08-02 06:27:25.921714+00	0	0	1906	1231	0	20	57	125	18	1	0	ok
2735	2026-08-02 06:28:25.923641+00	0	0	1906	1225	0	20	57	126	19	1	0	ok
2736	2026-08-02 06:29:25.922627+00	0	0	1906	1221	0	20	57	125	18	1	0	ok
2737	2026-08-02 06:30:25.923094+00	0	0	1906	1228	0	20	57	125	19	1	0	ok
2738	2026-08-02 06:31:25.923167+00	0	0	1906	1228	0	20	57	125	18	1	0	ok
2739	2026-08-02 06:32:25.923445+00	0	0	1906	1220	0	20	57	126	19	1	0	ok
2740	2026-08-02 06:33:25.924797+00	0	0.5	1906	1229	0	20	57	125	18	1	0	ok
2741	2026-08-02 06:34:25.923567+00	0	0	1906	1226	0	20	57	125	18	1	0	ok
2742	2026-08-02 06:35:25.925957+00	0.08	0	1906	1224	0	20	57	125	18	1	0	ok
2743	2026-08-02 06:36:25.926338+00	0.03	0	1906	1235	0	20	57	126	19	1	0	ok
2744	2026-08-02 06:37:25.928755+00	0.1	0.5	1906	1227	0	20	57	125	18	1	0	ok
2745	2026-08-02 06:38:25.927644+00	0.07	0	1906	1233	0	20	57	125	19	1	0	ok
2746	2026-08-02 06:39:25.927757+00	0.02	0	1906	1238	0	20	57	126	18	1	0	ok
2747	2026-08-02 06:40:25.927625+00	0.01	0	1906	1226	0	20	57	125	19	1	0	ok
2748	2026-08-02 06:41:25.927812+00	0	0.5	1906	1239	0	20	57	125	18	1	0	ok
2749	2026-08-02 06:42:25.929368+00	0	0	1906	1229	0	20	57	125	19	1	0	ok
2750	2026-08-02 06:43:25.930545+00	0	0	1906	1228	0	20	57	125	18	1	0	ok
2751	2026-08-02 06:44:25.92884+00	0.03	0	1906	1234	0	20	57	126	19	1	0	ok
2752	2026-08-02 06:45:14.917855+00	0.01	0	1906	1291	0	20	57	99	12	1	0	ok
2753	2026-08-02 06:46:14.918541+00	0	0	1906	1257	0	20	57	85	16	1	0	ok
2754	2026-08-02 06:47:14.92328+00	0.07	0	1906	1239	0	20	57	99	19	1	0	ok
2755	2026-08-02 06:48:14.920856+00	0.02	0.5	1906	1240	0	20	57	100	19	1	0	ok
2756	2026-08-02 06:49:14.922856+00	0.01	0	1906	1237	0	20	57	101	17	1	0	ok
2757	2026-08-02 06:50:14.923289+00	0.1	0	1906	1241	0	20	57	105	19	1	0	ok
2758	2026-08-02 06:51:14.923454+00	0.03	0	1906	1246	0	20	57	105	17	1	0	ok
2759	2026-08-02 06:52:14.925408+00	0.01	0.5	1906	1235	0	20	57	106	18	1	0	ok
2760	2026-08-02 06:53:14.925186+00	0.04	0	1906	1240	0	20	57	106	19	1	0	ok
2761	2026-08-02 06:54:14.923664+00	0.01	0.5	1906	1239	0	20	57	107	18	1	0	ok
2762	2026-08-02 06:55:14.924659+00	0	0	1906	1240	0	20	57	108	16	1	0	ok
2763	2026-08-02 06:56:14.926+00	0.16	0	1906	1245	0	20	57	102	18	1	0	ok
2764	2026-08-02 06:57:14.924234+00	0.06	0	1906	1253	0	20	57	104	18	1	0	ok
2765	2026-08-02 06:58:14.924111+00	0.02	0	1906	1249	0	20	57	104	19	1	0	ok
2766	2026-08-02 06:59:14.924547+00	0	0	1906	1248	0	20	57	104	18	1	0	ok
2767	2026-08-02 07:00:09.044317+00	0	1	1906	1297	0	20	57	99	13	1	0	ok
2768	2026-08-02 07:01:09.041062+00	0	0	1906	1256	0	20	57	88	20	1	0	ok
2769	2026-08-02 07:02:09.039731+00	0	0	1906	1261	0	20	57	92	14	1	0	ok
2770	2026-08-02 07:03:09.04008+00	0	0	1906	1233	0	20	57	103	19	1	0	ok
2771	2026-08-02 07:04:09.043867+00	0	0	1906	1231	0	20	57	104	17	1	0	ok
2772	2026-08-02 07:05:09.043319+00	0	0.5	1906	1254	0	20	57	104	17	1	0	ok
2773	2026-08-02 07:06:09.040266+00	0	0	1906	1250	0	20	57	103	16	1	0	ok
2774	2026-08-02 07:12:04.355918+00	0.08	0	1906	1289	0	20	57	98	12	1	0	ok
2775	2026-08-02 07:13:04.354145+00	0.03	0	1906	1258	0	20	57	91	19	1	0	ok
2776	2026-08-02 07:14:04.360761+00	0.08	2.49	1906	1252	0	20	57	96	17	1	0	ok
2777	2026-08-02 07:15:04.357934+00	0.03	0	1906	1248	0	20	57	97	18	1	0	ok
2778	2026-08-02 07:16:04.35862+00	0.01	0	1906	1251	0	20	57	97	19	1	0	ok
2779	2026-08-02 07:16:49.843138+00	0	0	1906	1299	0	20	57	99	12	1	0	ok
2780	2026-08-02 07:17:49.842469+00	0	0	1906	1268	0	20	57	91	12	1	0	ok
2781	2026-08-02 07:18:49.84295+00	0	0	1906	1255	0	20	57	101	13	1	0	ok
2782	2026-08-02 07:19:49.84343+00	0	0	1906	1251	0	20	57	103	12	1	0	ok
2783	2026-08-02 07:20:49.844653+00	0	0	1906	1248	0	20	57	102	13	1	0	ok
2784	2026-08-02 07:21:03.623108+00	0.08	0.5	1906	1264	0	20	57	100	14	1	0	ok
2785	2026-08-02 07:21:34.794891+00	0.05	0	1906	1285	0	20	57	99	14	1	0	ok
2786	2026-08-02 07:22:34.795106+00	0.09	0	1906	1259	0	20	57	92	9	1	0	ok
2787	2026-08-02 07:23:34.793669+00	0.27	0	1906	1246	0	20	57	95	10	1	0	ok
2788	2026-08-02 07:24:04.118756+00	0.41	0.5	1906	1286	0	20	57	98	11	1	0	ok
2789	2026-08-02 07:25:04.118849+00	0.15	0.5	1906	1240	0	20	57	93	17	1	0	ok
2790	2026-08-02 07:26:04.126578+00	0.05	0.5	1906	1240	0	20	57	98	18	1	0	ok
2791	2026-08-02 19:50:47.384065+00	0.08	0	1906	1289	0	20	58	99	12	1	0	ok
2792	2026-08-02 19:51:47.386184+00	0.03	0	1906	1265	0	20	58	85	10	1	0	ok
2793	2026-08-02 19:52:47.385413+00	0.16	0	1906	1265	0	20	58	90	10	1	0	ok
2794	2026-08-02 19:53:47.387593+00	0.28	0	1906	1270	0	20	58	91	10	1	0	ok
2795	2026-08-02 19:54:47.395693+00	0.1	0	1906	1248	0	20	58	97	12	1	0	ok
2796	2026-08-02 19:55:47.394368+00	0.04	0	1906	1262	0	20	58	99	11	1	0	ok
2797	2026-08-02 19:56:47.39415+00	0.07	0.5	1906	1248	0	20	58	98	11	1	0	ok
2798	2026-08-02 19:57:47.394331+00	0.08	0	1906	1257	0	20	58	102	10	1	0	ok
2799	2026-08-02 19:58:47.39584+00	0.03	0	1906	1246	0	20	58	105	11	1	0	ok
2800	2026-08-02 19:59:47.395368+00	0.01	0	1906	1247	0	20	58	106	10	1	0	ok
2801	2026-08-02 20:00:47.395744+00	0	0	1906	1246	0	20	58	104	11	1	0	ok
2802	2026-08-02 20:01:47.395306+00	0	0	1906	1242	0	20	58	104	10	1	0	ok
2803	2026-08-02 20:02:47.399249+00	0	0	1906	1243	0	20	58	104	11	1	0	ok
2804	2026-08-02 20:03:22.432363+00	0.08	0	1906	1279	0	20	58	98	12	1	0	ok
2805	2026-08-02 20:04:22.432156+00	0.03	0	1906	1263	0	20	58	87	15	1	0	ok
2806	2026-08-02 20:05:22.433408+00	0.01	0	1906	1252	0	20	58	93	13	1	0	ok
2807	2026-08-02 20:06:22.433802+00	0	0	1906	1255	0	20	58	96	15	1	0	ok
2808	2026-08-02 20:07:22.437492+00	0	0	1906	1252	0	20	58	99	15	1	0	ok
2809	2026-08-02 20:08:22.437519+00	0	0	1906	1242	0	20	58	100	18	1	0	ok
2810	2026-08-02 20:09:22.438384+00	0	0	1906	1241	0	20	58	100	18	1	0	ok
2811	2026-08-02 20:10:22.440813+00	0	0	1906	1247	0	20	58	100	19	1	0	ok
2812	2026-08-02 20:11:22.438234+00	0	0	1906	1248	0	20	58	103	18	1	0	ok
2813	2026-08-02 20:12:22.440808+00	0	0	1906	1238	0	20	58	103	17	1	0	ok
2814	2026-08-02 20:12:56.852545+00	0.08	0	1906	1291	0	20	58	98	12	1	0	ok
2815	2026-08-02 20:13:56.848915+00	0.03	0	1906	1272	0	20	58	89	10	1	0	ok
2816	2026-08-02 20:14:56.853609+00	0.01	0	1906	1263	0	20	58	97	11	1	0	ok
2817	2026-08-02 20:15:56.85303+00	0	0	1906	1265	0	20	58	98	10	1	0	ok
2818	2026-08-02 20:16:54.26517+00	0	0	1906	1292	0	20	58	98	12	1	0	ok
2819	2026-08-02 20:17:54.26368+00	0	0	1906	1265	0	20	58	89	10	1	0	ok
2820	2026-08-02 20:18:54.2663+00	0	0	1906	1263	0	20	58	99	10	1	0	ok
2821	2026-08-02 20:19:54.268317+00	0	0	1906	1260	0	20	58	100	10	1	0	ok
2822	2026-08-02 20:20:54.266987+00	0	0	1906	1253	0	20	58	100	10	1	0	ok
2823	2026-08-02 20:21:54.267946+00	0	0	1906	1232	0	20	58	100	10	1	0	ok
2824	2026-08-02 20:22:54.267898+00	0	0	1906	1260	0	20	58	101	10	1	0	ok
2825	2026-08-02 20:23:54.270881+00	0	0	1906	1253	0	20	58	102	10	1	0	ok
2826	2026-08-02 20:24:54.27154+00	0	0	1906	1250	0	20	58	102	10	1	0	ok
2827	2026-08-02 20:25:54.271797+00	0	0	1906	1257	0	20	58	103	10	1	0	ok
2828	2026-08-02 20:26:54.274875+00	0	0.5	1906	1257	0	20	58	103	10	1	0	ok
2829	2026-08-02 20:27:54.272813+00	0	0	1906	1259	0	20	58	103	10	1	0	ok
2830	2026-08-02 20:28:54.271895+00	0	0	1906	1247	0	20	58	103	11	1	0	ok
2831	2026-08-02 20:29:35.822973+00	0	0	1906	1290	0	20	58	99	12	1	0	ok
2832	2026-08-02 20:30:35.823847+00	0	0	1906	1266	0	20	58	90	12	1	0	ok
2833	2026-08-02 20:31:35.826509+00	0	0	1906	1252	0	20	58	102	12	1	0	ok
2834	2026-08-02 20:32:35.829609+00	0	0	1906	1255	0	20	58	103	10	1	0	ok
2835	2026-08-02 20:33:35.831295+00	0	0	1906	1266	0	20	58	103	12	1	0	ok
2836	2026-08-02 20:34:35.829516+00	0.37	0	1906	1252	0	20	58	102	11	1	0	ok
2837	2026-08-02 20:35:35.828936+00	0.13	0	1906	1256	0	20	58	103	11	1	0	ok
2838	2026-08-02 20:36:35.831952+00	0.05	0	1906	1251	0	20	58	106	12	1	0	ok
2839	2026-08-02 20:37:35.830517+00	0.02	0	1906	1245	0	20	58	103	19	1	0	ok
2840	2026-08-02 20:38:35.830257+00	0	0	1906	1240	0	20	58	106	12	1	0	ok
2841	2026-08-02 20:39:35.829374+00	0	0	1906	1249	0	20	58	108	13	1	0	ok
2842	2026-08-02 20:40:35.829292+00	0	0	1906	1253	0	20	58	108	12	1	0	ok
2843	2026-08-02 20:41:35.830116+00	0	0	1906	1245	0	20	58	108	12	1	0	ok
2844	2026-08-02 20:42:35.828996+00	0	0	1906	1249	0	20	58	109	9	1	0	ok
2845	2026-08-02 20:43:35.829+00	0.34	0	1906	1259	0	20	58	109	9	1	0	ok
2846	2026-08-02 20:44:35.829021+00	0.12	0	1906	1246	0	20	58	110	15	1	0	ok
2847	2026-08-02 20:45:35.831287+00	0.04	0	1906	1248	0	20	58	110	9	1	0	ok
2848	2026-08-02 20:46:35.830414+00	0.01	0	1906	1261	0	20	58	110	9	1	0	ok
2849	2026-08-02 20:47:35.830648+00	0	0	1906	1248	0	20	58	111	12	1	0	ok
2850	2026-08-02 20:48:35.830784+00	0	0	1906	1246	0	20	58	110	11	1	0	ok
2851	2026-08-02 20:49:35.831046+00	0	0	1906	1240	0	20	58	111	11	1	0	ok
2852	2026-08-02 20:50:35.831495+00	0	0	1906	1241	0	20	58	112	11	1	0	ok
2853	2026-08-02 20:51:35.831434+00	0.29	0	1906	1248	0	20	58	112	10	1	0	ok
2854	2026-08-02 20:52:35.832364+00	0.1	0	1906	1234	0	20	58	112	11	1	0	ok
2855	2026-08-02 20:53:35.834325+00	0.04	0	1906	1253	0	20	58	112	10	1	0	ok
2856	2026-08-02 20:54:35.839809+00	0.01	0	1906	1253	0	20	58	113	10	1	0	ok
2857	2026-08-02 20:55:35.831918+00	0.29	0	1906	1246	0	20	58	113	10	1	0	ok
2858	2026-08-02 20:56:35.833051+00	0.11	0	1906	1243	0	20	58	114	10	1	0	ok
2859	2026-08-02 20:57:35.831455+00	0.04	0	1906	1245	0	20	58	113	11	1	0	ok
2860	2026-08-02 20:58:35.83371+00	0.01	0	1906	1249	0	20	58	114	11	1	0	ok
2861	2026-08-02 20:59:35.831879+00	0.29	0	1906	1243	0	20	58	113	10	1	0	ok
2862	2026-08-02 21:00:35.833771+00	0.17	0	1906	1244	0	20	58	113	10	1	0	ok
2863	2026-08-02 21:01:35.835292+00	0.3	0	1906	1239	0	20	58	114	11	1	0	ok
2864	2026-08-02 21:02:35.833102+00	0.11	0	1906	1245	0	20	58	115	11	1	0	ok
2865	2026-08-02 21:03:35.834156+00	0.04	0	1906	1243	0	20	58	113	10	1	0	ok
2866	2026-08-02 21:04:35.83363+00	0.29	0	1906	1250	0	20	58	113	10	1	0	ok
2867	2026-08-02 21:05:35.833619+00	0.1	0	1906	1247	0	20	58	113	11	1	0	ok
2868	2026-08-02 21:06:35.83252+00	0.04	0	1906	1241	0	20	58	114	10	1	0	ok
2869	2026-08-02 21:07:35.835593+00	0.01	0	1906	1250	0	20	58	114	12	1	0	ok
2870	2026-08-02 21:08:35.837864+00	0	0	1906	1238	0	20	58	113	11	1	0	ok
2871	2026-08-02 21:09:35.837098+00	0	0	1906	1241	0	20	58	115	11	1	0	ok
2872	2026-08-02 21:10:35.836906+00	0.48	0	1906	1239	0	20	58	114	10	1	0	ok
2873	2026-08-02 21:11:35.836802+00	0.52	0	1906	1249	0	20	58	116	10	1	0	ok
2874	2026-08-02 21:12:35.837175+00	0.19	0	1906	1244	0	20	58	116	12	1	0	ok
2875	2026-08-02 21:13:35.837752+00	0.07	0	1906	1238	0	20	58	115	10	1	0	ok
2876	2026-08-02 21:14:35.83803+00	0.02	0	1906	1235	0	20	58	115	10	1	0	ok
2877	2026-08-02 21:15:35.837139+00	0.07	0	1906	1235	0	20	58	115	10	1	0	ok
2878	2026-08-02 21:16:35.837418+00	0.03	0	1906	1244	0	20	58	115	10	1	0	ok
2879	2026-08-02 21:17:35.837046+00	0.01	0	1906	1248	0	20	58	115	11	1	0	ok
2880	2026-08-02 21:18:35.83814+00	0.39	0	1906	1246	0	20	58	115	12	1	0	ok
2881	2026-08-02 21:19:35.838248+00	0.14	0	1906	1240	0	20	58	116	13	1	0	ok
2882	2026-08-02 21:20:35.841162+00	0.08	0	1906	1241	0	20	58	115	12	1	0	ok
2883	2026-08-02 21:21:35.839343+00	0.03	0	1906	1247	0	20	58	115	14	1	0	ok
2884	2026-08-02 21:22:35.840214+00	0.25	0	1906	1236	0	20	58	115	10	1	0	ok
2885	2026-08-02 21:23:35.839511+00	0.19	0	1906	1248	0	20	58	116	12	1	0	ok
2886	2026-08-02 21:24:35.839443+00	0.12	0	1906	1233	0	20	58	116	10	1	0	ok
2887	2026-08-02 21:25:35.842191+00	0.04	0.5	1906	1231	0	20	58	116	14	1	0	ok
2888	2026-08-02 21:26:35.840807+00	0.01	0	1906	1238	0	20	58	116	12	1	0	ok
2889	2026-08-02 21:27:35.841966+00	0	0	1906	1246	0	20	58	116	12	1	0	ok
2890	2026-08-02 21:28:35.842795+00	0.24	0	1906	1249	0	20	58	116	11	1	0	ok
2891	2026-08-02 21:29:35.842581+00	0.23	0	1906	1250	0	20	58	116	12	1	0	ok
2892	2026-08-02 21:30:35.842508+00	0.33	0	1906	1238	0	20	58	115	10	1	0	ok
2893	2026-08-02 21:31:35.84224+00	0.36	0	1906	1235	0	20	58	116	11	1	0	ok
2894	2026-08-02 21:32:35.841919+00	0.33	0.5	1906	1237	0	20	58	116	10	1	0	ok
2895	2026-08-02 21:33:35.843234+00	0.2	0	1906	1242	0	20	58	115	10	1	0	ok
2896	2026-08-02 21:34:35.844886+00	0.56	0	1906	1234	0	20	58	115	11	1	0	ok
2897	2026-08-02 21:35:35.847125+00	0.2	0	1906	1237	0	20	58	117	12	1	0	ok
2898	2026-08-02 21:36:35.843522+00	0.32	0	1906	1242	0	20	58	115	10	1	0	ok
2899	2026-08-02 21:37:35.846273+00	0.18	0	1906	1236	0	20	58	116	11	1	0	ok
2900	2026-08-02 21:38:35.844257+00	0.4	0	1906	1235	0	20	58	115	10	1	0	ok
2901	2026-08-02 21:39:35.844867+00	0.39	0	1906	1246	0	20	58	115	10	1	0	ok
2902	2026-08-02 21:40:35.845491+00	0.22	0	1906	1243	0	20	58	116	10	1	0	ok
2903	2026-08-02 21:41:35.847918+00	0.13	0	1906	1236	0	20	58	116	13	1	0	ok
2904	2026-08-02 21:42:35.851431+00	0.09	0	1906	1242	0	20	58	116	12	1	0	ok
2905	2026-08-02 21:43:35.851906+00	0.37	0	1906	1243	0	20	58	117	11	1	0	ok
2906	2026-08-02 21:44:35.851256+00	0.13	0	1906	1239	0	20	58	116	11	1	0	ok
2907	2026-08-02 21:45:35.854407+00	0.05	0	1906	1234	0	20	58	116	13	1	0	ok
2908	2026-08-02 21:46:35.854851+00	0.16	0	1906	1235	0	20	58	116	10	1	0	ok
2909	2026-08-02 21:47:35.853805+00	0.06	0	1906	1251	0	20	58	117	13	1	0	ok
2910	2026-08-02 21:48:35.854951+00	0.26	0.5	1906	1241	0	20	58	116	11	1	0	ok
2911	2026-08-02 21:49:35.85681+00	0.39	0	1906	1255	0	20	58	110	12	1	0	ok
2912	2026-08-02 21:50:35.856972+00	0.62	0	1906	1250	0	20	58	109	10	1	0	ok
2913	2026-08-02 21:51:35.856229+00	0.47	0	1906	1239	0	20	58	111	12	1	0	ok
2914	2026-08-02 21:52:35.855153+00	0.41	0.5	1906	1241	0	20	58	111	10	1	0	ok
2915	2026-08-02 21:53:35.856303+00	0.25	0	1906	1243	0	20	58	113	11	1	0	ok
2916	2026-08-02 21:54:35.8586+00	0.09	0	1906	1242	0	20	58	114	10	1	0	ok
2917	2026-08-02 21:55:35.856857+00	0.32	0	1906	1239	0	20	58	114	12	1	0	ok
2918	2026-08-02 21:56:35.855773+00	0.16	0.5	1906	1241	0	20	58	114	11	1	0	ok
2919	2026-08-02 21:57:35.855884+00	0.06	0	1906	1249	0	20	58	114	11	1	0	ok
2920	2026-08-02 21:58:35.857419+00	0.26	0	1906	1245	0	20	58	114	11	1	0	ok
2921	2026-08-02 21:59:35.856107+00	0.34	0	1906	1236	0	20	58	115	11	1	0	ok
2922	2026-08-02 22:00:35.857646+00	0.41	0	1906	1245	0	20	58	115	10	1	0	ok
2923	2026-08-02 22:01:35.858295+00	0.44	0	1906	1242	0	20	58	115	10	1	0	ok
2924	2026-08-02 22:02:35.856148+00	0.4	0.5	1906	1237	0	20	58	114	10	1	0	ok
2925	2026-08-02 22:03:35.857234+00	0.29	0	1906	1251	0	20	58	115	10	1	0	ok
2926	2026-08-02 22:04:35.855513+00	0.36	0	1906	1248	0	20	58	114	10	1	0	ok
2927	2026-08-02 22:05:35.857223+00	0.32	0	1906	1240	0	20	58	115	11	1	0	ok
2928	2026-08-02 22:06:35.855665+00	0.21	0	1906	1246	0	20	58	115	10	1	0	ok
2929	2026-08-02 22:07:35.857369+00	0.25	0	1906	1233	0	20	58	115	10	1	0	ok
2930	2026-08-02 22:08:35.855862+00	0.09	0.5	1906	1246	0	20	58	115	10	1	0	ok
2931	2026-08-02 22:09:35.857601+00	0.4	0	1906	1234	0	20	58	115	10	1	0	ok
2932	2026-08-02 22:10:35.85717+00	0.39	0	1906	1239	0	20	58	115	10	1	0	ok
2933	2026-08-02 22:11:35.858522+00	0.53	0	1906	1248	0	20	58	115	11	1	0	ok
2934	2026-08-02 22:12:35.857895+00	0.19	0	1906	1232	0	20	58	116	10	1	0	ok
2935	2026-08-02 22:13:35.860017+00	0.07	0	1906	1248	0	20	58	115	12	1	0	ok
2936	2026-08-02 22:14:35.860726+00	0.36	0	1906	1247	0	20	58	115	10	1	0	ok
2937	2026-08-02 22:15:35.864948+00	0.52	1.01	1906	1239	0	20	58	115	10	1	0	ok
2938	2026-08-02 22:16:35.860105+00	0.29	0	1906	1243	0	20	58	115	10	1	0	ok
2939	2026-08-02 22:17:35.859649+00	0.1	0	1906	1234	0	20	58	115	11	1	0	ok
2940	2026-08-02 22:18:35.86064+00	0.28	0	1906	1234	0	20	58	116	11	1	0	ok
2941	2026-08-02 22:19:35.86108+00	0.44	0.5	1906	1242	0	20	58	115	12	1	0	ok
2942	2026-08-02 22:20:35.862304+00	0.4	0	1906	1232	0	20	58	115	11	1	0	ok
2943	2026-08-02 22:21:35.863793+00	0.39	0	1906	1234	0	20	58	115	12	1	0	ok
2944	2026-08-02 22:22:35.860708+00	0.36	0	1906	1239	0	20	58	115	10	1	0	ok
2945	2026-08-02 22:23:35.864514+00	0.27	0	1906	1247	0	20	58	116	12	1	0	ok
2946	2026-08-02 22:24:35.863852+00	0.39	0	1906	1237	0	20	58	115	10	1	0	ok
2947	2026-08-02 22:25:35.866921+00	0.38	0	1906	1241	0	20	58	116	12	1	0	ok
2948	2026-08-02 22:26:35.869569+00	0.48	0	1906	1242	0	20	58	116	10	1	0	ok
2949	2026-08-02 22:27:35.867414+00	0.51	0	1906	1251	0	20	58	116	12	1	0	ok
2950	2026-08-02 22:28:35.867469+00	0.4	0	1906	1243	0	20	58	116	10	1	0	ok
2951	2026-08-02 22:29:35.86928+00	0.44	0	1906	1231	0	20	58	115	11	1	0	ok
2952	2026-08-02 22:30:35.867835+00	0.45	0	1906	1239	0	20	58	116	10	1	0	ok
2953	2026-08-02 22:31:35.875416+00	0.31	0	1906	1243	0	20	58	116	12	1	0	ok
2954	2026-08-02 22:32:35.875797+00	0.28	0	1906	1237	0	20	58	116	10	1	0	ok
2955	2026-08-02 22:33:35.874536+00	0.1	0.51	1906	1239	0	20	58	116	12	1	0	ok
2956	2026-08-02 22:34:35.878271+00	0.04	0	1906	1246	0	20	58	116	11	1	0	ok
2957	2026-08-02 22:35:35.876586+00	0.25	0.5	1906	1238	0	20	58	115	11	1	0	ok
2958	2026-08-02 22:36:35.876493+00	0.49	0	1906	1237	0	20	58	116	10	1	0	ok
2959	2026-08-02 22:37:35.876496+00	0.45	0	1906	1241	0	20	58	116	11	1	0	ok
2960	2026-08-02 22:38:35.875199+00	0.41	0	1906	1244	0	20	58	116	10	1	0	ok
2961	2026-08-02 22:39:35.8754+00	0.2	0	1906	1241	0	20	58	116	10	1	0	ok
2962	2026-08-02 22:40:35.875273+00	0.41	0	1906	1248	0	20	58	116	10	1	0	ok
2963	2026-08-02 22:41:35.876847+00	0.25	0	1906	1242	0	20	58	117	10	1	0	ok
2964	2026-08-02 22:42:35.878175+00	0.33	0	1906	1236	0	20	58	116	10	1	0	ok
2965	2026-08-02 22:43:35.878095+00	0.38	0	1906	1234	0	20	58	117	10	1	0	ok
2966	2026-08-02 22:44:35.87797+00	0.14	0	1906	1233	0	20	58	116	10	1	0	ok
2967	2026-08-02 22:45:35.878071+00	0.53	0	1906	1234	0	20	58	117	10	1	0	ok
2968	2026-08-02 22:46:35.879636+00	0.19	0	1906	1241	0	20	58	117	10	1	0	ok
2969	2026-08-02 22:47:35.877692+00	0.07	0	1906	1238	0	20	58	117	10	1	0	ok
2970	2026-08-02 22:48:35.877283+00	0.02	0	1906	1249	0	20	58	117	10	1	0	ok
2971	2026-08-02 22:49:35.87842+00	0.01	0.5	1906	1250	0	20	58	117	11	1	0	ok
2972	2026-08-02 22:50:35.878462+00	0.34	0	1906	1236	0	20	58	116	10	1	0	ok
2973	2026-08-02 22:51:35.879199+00	0.25	0	1906	1247	0	20	58	117	10	1	0	ok
2974	2026-08-02 22:52:35.879432+00	0.09	0	1906	1234	0	20	58	117	10	1	0	ok
2975	2026-08-02 22:53:35.878868+00	0.03	0	1906	1231	0	20	58	117	10	1	0	ok
2976	2026-08-02 22:54:35.878704+00	0.01	0	1906	1238	0	20	58	117	10	1	0	ok
2977	2026-08-02 22:55:35.880381+00	0	0	1906	1231	0	20	58	117	10	1	0	ok
2978	2026-08-02 22:56:35.880574+00	0.22	0	1906	1243	0	20	58	117	10	1	0	ok
2979	2026-08-02 22:57:35.879494+00	0.08	0	1906	1248	0	20	58	117	10	1	0	ok
2980	2026-08-02 22:58:35.881077+00	0.03	0	1906	1236	0	20	58	117	10	1	0	ok
2981	2026-08-02 22:59:35.881626+00	0.01	0	1906	1246	0	20	58	117	10	1	0	ok
2982	2026-08-02 23:00:35.882101+00	0.15	0	1906	1236	0	20	58	116	10	1	0	ok
2983	2026-08-02 23:01:35.88227+00	0.05	0	1906	1235	0	20	58	117	10	1	0	ok
2984	2026-08-02 23:02:35.884231+00	0.02	0	1906	1232	0	20	58	117	10	1	0	ok
2985	2026-08-02 23:03:35.883107+00	0	0	1906	1234	0	20	58	118	10	1	0	ok
2986	2026-08-02 23:04:35.88199+00	0.05	0	1906	1242	0	20	58	117	10	1	0	ok
2987	2026-08-02 23:05:35.883013+00	0.02	0	1906	1242	0	20	58	118	10	1	0	ok
2988	2026-08-02 23:06:35.882784+00	0	0	1906	1241	0	20	58	118	10	1	0	ok
2989	2026-08-02 23:07:35.884944+00	0	0	1906	1233	0	20	58	118	10	1	0	ok
2990	2026-08-02 23:08:35.884087+00	0	0	1906	1237	0	20	58	118	10	1	0	ok
2991	2026-08-02 23:09:35.885113+00	0	0	1906	1235	0	20	58	118	10	1	0	ok
2992	2026-08-02 23:10:35.885523+00	0	0	1906	1233	0	20	58	118	10	1	0	ok
2993	2026-08-02 23:11:35.886224+00	0	0.5	1906	1235	0	20	58	118	10	1	0	ok
2994	2026-08-02 23:12:35.887922+00	0	0	1906	1241	0	20	58	118	10	1	0	ok
2995	2026-08-02 23:13:35.886609+00	0.1	0	1906	1232	0	20	58	118	10	1	0	ok
2996	2026-08-02 23:14:35.88743+00	0.04	0	1906	1243	0	20	58	118	10	1	0	ok
2997	2026-08-02 23:15:35.89042+00	0.01	0	1906	1246	0	20	58	118	10	1	0	ok
2998	2026-08-02 23:16:35.889111+00	0	0	1906	1244	0	20	58	118	10	1	0	ok
2999	2026-08-02 23:17:35.889564+00	0	0	1906	1233	0	20	58	119	10	1	0	ok
3000	2026-08-02 23:18:35.891651+00	0	0	1906	1230	0	20	58	117	10	1	0	ok
3001	2026-08-02 23:19:35.891305+00	0	0	1906	1245	0	20	58	117	10	1	0	ok
3002	2026-08-02 23:20:35.889681+00	0.04	0	1906	1242	0	20	58	117	10	1	0	ok
3003	2026-08-02 23:21:35.892238+00	0.01	0	1906	1235	0	20	58	118	10	1	0	ok
3004	2026-08-02 23:22:35.892374+00	0	0	1906	1233	0	20	58	118	10	1	0	ok
3005	2026-08-02 23:23:35.894417+00	0	0	1906	1235	0	20	58	118	10	1	0	ok
3006	2026-08-02 23:24:35.892779+00	0	0	1906	1239	0	20	58	118	10	1	0	ok
3007	2026-08-02 23:25:35.894484+00	0	0	1906	1249	0	20	58	119	10	1	0	ok
3008	2026-08-02 23:26:35.894419+00	0.04	0	1906	1230	0	20	58	119	10	1	0	ok
3009	2026-08-02 23:27:35.895222+00	0.01	0.5	1906	1240	0	20	58	118	10	1	0	ok
3010	2026-08-02 23:28:35.896152+00	0	0	1906	1230	0	20	58	118	10	1	0	ok
3011	2026-08-02 23:29:35.897719+00	0	0	1906	1235	0	20	58	119	10	1	0	ok
3012	2026-08-02 23:30:35.898361+00	0.05	0	1906	1234	0	20	58	119	10	1	0	ok
3013	2026-08-02 23:31:35.900488+00	0.02	0	1906	1245	0	20	58	118	10	1	0	ok
3014	2026-08-02 23:32:35.900513+00	0.04	0	1906	1236	0	20	58	119	9	1	0	ok
3015	2026-08-02 23:33:35.904156+00	0.01	0	1906	1231	0	20	58	120	10	1	0	ok
3016	2026-08-02 23:34:35.902546+00	0.08	0	1906	1235	0	20	58	119	10	1	0	ok
3017	2026-08-02 23:35:35.903597+00	0.03	0	1906	1239	0	20	58	118	10	1	0	ok
3018	2026-08-02 23:36:35.904374+00	0.01	0	1906	1230	0	20	58	118	10	1	0	ok
3019	2026-08-02 23:37:35.906455+00	0	0	1906	1241	0	20	58	119	10	1	0	ok
3020	2026-08-02 23:38:35.905678+00	0	0	1906	1228	0	20	58	119	10	1	0	ok
3021	2026-08-02 23:39:35.908063+00	0	0	1906	1237	0	20	58	119	10	1	0	ok
3022	2026-08-02 23:40:35.907372+00	0	0.5	1906	1230	0	20	58	119	10	1	0	ok
3023	2026-08-02 23:41:35.909974+00	0	0	1906	1232	0	20	58	119	11	1	0	ok
3024	2026-08-02 23:42:35.909437+00	0	0	1906	1241	0	20	58	118	10	1	0	ok
3025	2026-08-02 23:43:35.912732+00	0	0	1906	1231	0	20	58	119	12	1	0	ok
3026	2026-08-02 23:44:35.911813+00	0.15	0	1906	1229	0	20	58	119	11	1	0	ok
3027	2026-08-02 23:45:35.913164+00	0.05	0	1906	1237	0	20	58	119	12	1	0	ok
3028	2026-08-02 23:46:35.913415+00	0.02	0	1906	1237	0	20	58	118	12	1	0	ok
3029	2026-08-02 23:47:35.913989+00	0	0	1906	1231	0	20	58	119	12	1	0	ok
3030	2026-08-02 23:48:35.913586+00	0	0	1906	1233	0	20	58	118	12	1	0	ok
3031	2026-08-02 23:49:35.914388+00	0	0	1906	1230	0	20	58	119	12	1	0	ok
3032	2026-08-02 23:50:35.912706+00	0	0	1906	1243	0	20	58	119	12	1	0	ok
3033	2026-08-02 23:51:35.914839+00	0	0	1906	1248	0	20	58	119	12	1	0	ok
3034	2026-08-02 23:52:35.913366+00	0	0	1906	1238	0	20	58	119	12	1	0	ok
3035	2026-08-02 23:53:35.914195+00	0	0	1906	1232	0	20	58	119	12	1	0	ok
3036	2026-08-02 23:54:35.914285+00	0	0	1906	1233	0	20	58	119	11	1	0	ok
3037	2026-08-02 23:55:35.91391+00	0	0	1906	1246	0	20	58	120	11	1	0	ok
3038	2026-08-02 23:56:35.912721+00	0.08	0	1906	1230	0	20	58	118	11	1	0	ok
3039	2026-08-02 23:57:35.916296+00	0.03	0	1906	1239	0	20	58	119	12	1	0	ok
3040	2026-08-02 23:58:35.914326+00	0.01	0	1906	1233	0	20	58	119	12	1	0	ok
3041	2026-08-02 23:59:35.914162+00	0	0	1906	1235	0	20	58	120	12	1	0	ok
3042	2026-08-03 00:00:35.914641+00	0	0	1906	1245	0	20	58	119	12	1	0	ok
3043	2026-08-03 00:01:35.915903+00	0.04	0.5	1906	1229	0	20	58	119	12	1	0	ok
3044	2026-08-03 00:02:35.915616+00	0.01	0	1906	1240	0	20	58	119	12	1	0	ok
3045	2026-08-03 00:03:35.914961+00	0	0	1906	1231	0	20	58	119	12	1	0	ok
3046	2026-08-03 00:04:35.915594+00	0	0.5	1906	1240	0	20	58	119	12	1	0	ok
3047	2026-08-03 00:05:35.915853+00	0.05	0	1906	1232	0	20	58	120	12	1	0	ok
3048	2026-08-03 00:06:35.915484+00	0.02	0	1906	1244	0	20	58	119	12	1	0	ok
3049	2026-08-03 00:07:35.916962+00	0	0	1906	1240	0	20	58	120	11	1	0	ok
3050	2026-08-03 00:08:35.916764+00	0	0	1906	1230	0	20	58	119	12	1	0	ok
3051	2026-08-03 00:09:35.917182+00	0	0	1906	1233	0	20	58	119	12	1	0	ok
3052	2026-08-03 00:10:35.918263+00	0	0	1906	1231	0	20	58	119	12	1	0	ok
3053	2026-08-03 00:11:35.921897+00	0.05	0	1906	1230	0	20	58	119	11	1	0	ok
3054	2026-08-03 00:12:35.918029+00	0.02	0	1906	1235	0	20	58	119	11	1	0	ok
3055	2026-08-03 00:13:35.920376+00	0	0	1906	1229	0	20	58	119	12	1	0	ok
3056	2026-08-03 00:14:35.920631+00	0	0	1906	1242	0	20	58	119	11	1	0	ok
3057	2026-08-03 00:15:35.922054+00	0	0	1906	1234	0	20	58	120	12	1	0	ok
3058	2026-08-03 00:16:35.920984+00	0	0.5	1906	1228	0	20	58	119	11	1	0	ok
3059	2026-08-03 00:17:35.920881+00	0	0	1906	1243	0	20	58	119	12	1	0	ok
3060	2026-08-03 00:18:35.921268+00	0	0	1906	1236	0	20	58	120	12	1	0	ok
3061	2026-08-03 00:19:35.922369+00	0	0	1906	1227	0	20	58	119	11	1	0	ok
3062	2026-08-03 00:20:35.922341+00	0.05	0	1906	1239	0	20	58	119	11	1	0	ok
3063	2026-08-03 00:21:35.923624+00	0.13	0	1906	1240	0	20	58	119	11	1	0	ok
3064	2026-08-03 00:22:35.923958+00	0.05	0	1906	1243	0	20	58	120	11	1	0	ok
3065	2026-08-03 00:23:35.923846+00	0.02	0	1906	1227	0	20	58	120	11	1	0	ok
3066	2026-08-03 00:24:35.924496+00	0	0	1906	1229	0	20	58	120	11	1	0	ok
3067	2026-08-03 00:25:35.925715+00	0	0	1906	1241	0	20	58	119	11	1	0	ok
3068	2026-08-03 00:26:35.923888+00	0	0	1906	1230	0	20	58	120	11	1	0	ok
3069	2026-08-03 00:27:35.925032+00	0	0	1906	1231	0	20	58	119	11	1	0	ok
3070	2026-08-03 00:28:35.925643+00	0	0	1906	1243	0	20	58	119	10	1	0	ok
3071	2026-08-03 00:29:35.925854+00	0	0	1906	1239	0	20	58	120	10	1	0	ok
3072	2026-08-03 00:30:35.925566+00	0	0	1906	1230	0	20	58	120	10	1	0	ok
3073	2026-08-03 00:31:35.926751+00	0	0	1906	1237	0	20	58	120	10	1	0	ok
3074	2026-08-03 00:32:35.926659+00	0	0.5	1906	1248	0	20	58	119	11	1	0	ok
3075	2026-08-03 00:33:35.926221+00	0.13	0	1906	1235	0	20	58	119	12	1	0	ok
3076	2026-08-03 00:34:35.925673+00	0.05	0	1906	1230	0	20	58	119	13	1	0	ok
3077	2026-08-03 00:35:35.927511+00	0.02	0	1906	1231	0	20	58	120	13	1	0	ok
3078	2026-08-03 00:36:35.929006+00	0	0	1906	1227	0	20	58	120	13	1	0	ok
3079	2026-08-03 00:37:35.930128+00	0	0	1906	1228	0	20	58	119	13	1	0	ok
3080	2026-08-03 00:38:35.93044+00	0	0	1906	1225	0	20	58	120	13	1	0	ok
3081	2026-08-03 00:39:35.93228+00	0	0	1906	1230	0	20	58	120	11	1	0	ok
3082	2026-08-03 00:40:35.93256+00	0	0	1906	1237	0	20	58	121	11	1	0	ok
3083	2026-08-03 00:41:35.933928+00	0	0	1906	1234	0	20	58	120	11	1	0	ok
3084	2026-08-03 00:42:35.932791+00	0	0	1906	1234	0	20	58	120	11	1	0	ok
3085	2026-08-03 00:43:35.934489+00	0	0	1906	1244	0	20	58	120	11	1	0	ok
3086	2026-08-03 00:44:35.932982+00	0	0	1906	1235	0	20	58	120	12	1	0	ok
3087	2026-08-03 00:45:35.936368+00	0	0	1906	1229	0	20	58	120	12	1	0	ok
3088	2026-08-03 00:46:35.935437+00	0	0	1906	1234	0	20	58	120	11	1	0	ok
3089	2026-08-03 00:47:35.934748+00	0.04	0	1906	1241	0	20	58	120	12	1	0	ok
3090	2026-08-03 00:48:35.937037+00	0.01	0	1906	1238	0	20	58	120	12	1	0	ok
3091	2026-08-03 00:49:35.941522+00	0	0	1906	1244	0	20	58	119	11	1	0	ok
3092	2026-08-03 00:50:35.939789+00	0	0	1906	1232	0	20	58	120	11	1	0	ok
3093	2026-08-03 00:51:35.939492+00	0	0	1906	1244	0	20	58	120	12	1	0	ok
3094	2026-08-03 00:52:35.939727+00	0.05	0	1906	1234	0	20	58	120	12	1	0	ok
3095	2026-08-03 00:53:35.941195+00	0.02	0	1906	1240	0	20	58	119	11	1	0	ok
3096	2026-08-03 00:54:35.940274+00	0	0	1906	1227	0	20	58	120	11	1	0	ok
3097	2026-08-03 00:55:35.940669+00	0	0	1906	1239	0	20	58	120	12	1	0	ok
3098	2026-08-03 00:56:35.941764+00	0	0	1906	1246	0	20	58	119	11	1	0	ok
3099	2026-08-03 00:57:35.943282+00	0	0	1906	1238	0	20	58	120	12	1	0	ok
3100	2026-08-03 00:58:35.943683+00	0	0	1906	1235	0	20	58	120	12	1	0	ok
3101	2026-08-03 00:59:35.945586+00	0	0	1906	1229	0	20	58	121	12	1	0	ok
3102	2026-08-03 01:00:35.945924+00	0	0	1906	1228	0	20	58	120	12	1	0	ok
3103	2026-08-03 01:01:35.94681+00	0	0.5	1906	1237	0	20	58	121	12	1	0	ok
3104	2026-08-03 01:02:35.948184+00	0	0	1906	1244	0	20	58	119	12	1	0	ok
3105	2026-08-03 01:03:35.948697+00	0	0	1906	1234	0	20	58	121	12	1	0	ok
3106	2026-08-03 01:04:35.948523+00	0	0	1906	1238	0	20	58	120	12	1	0	ok
3107	2026-08-03 01:05:35.948738+00	0	0	1906	1233	0	20	58	119	12	1	0	ok
3108	2026-08-03 01:06:35.950402+00	0	0	1906	1238	0	20	58	120	12	1	0	ok
3109	2026-08-03 01:07:35.951039+00	0	0	1906	1236	0	20	58	121	12	1	0	ok
3110	2026-08-03 01:08:35.949195+00	0	0	1906	1231	0	20	58	120	12	1	0	ok
3111	2026-08-03 01:09:35.95054+00	0	0	1906	1237	0	20	58	120	12	1	0	ok
3112	2026-08-03 01:10:35.949738+00	0	0	1906	1240	0	20	58	120	12	1	0	ok
3113	2026-08-03 01:11:35.949478+00	0	0	1906	1244	0	20	58	120	12	1	0	ok
3114	2026-08-03 01:12:35.948199+00	0	0	1906	1234	0	20	58	120	12	1	0	ok
3115	2026-08-03 01:13:35.949715+00	0	0.5	1906	1235	0	20	58	120	12	1	0	ok
3116	2026-08-03 01:14:35.948198+00	0	0	1906	1228	0	20	58	120	12	1	0	ok
3117	2026-08-03 01:15:35.949183+00	0	0	1906	1233	0	20	58	120	12	1	0	ok
3118	2026-08-03 01:16:35.951938+00	0	0	1906	1234	0	20	58	119	12	1	0	ok
3119	2026-08-03 01:17:35.951009+00	0	0	1906	1227	0	20	58	120	12	1	0	ok
3120	2026-08-03 01:18:35.949678+00	0	0	1906	1243	0	20	58	120	12	1	0	ok
3121	2026-08-03 01:19:35.949192+00	0	0	1906	1229	0	20	58	120	12	1	0	ok
3122	2026-08-03 01:20:35.950242+00	0	0	1906	1235	0	20	58	120	12	1	0	ok
3123	2026-08-03 01:21:35.950384+00	0	0	1906	1233	0	20	58	120	11	1	0	ok
3124	2026-08-03 01:22:35.950688+00	0	0	1906	1227	0	20	58	120	12	1	0	ok
3125	2026-08-03 01:23:35.951069+00	0	0	1906	1245	0	20	58	120	12	1	0	ok
3126	2026-08-03 01:24:35.952578+00	0	0	1906	1232	0	20	58	120	12	1	0	ok
3127	2026-08-03 01:25:35.951412+00	0	0	1906	1230	0	20	58	120	12	1	0	ok
3128	2026-08-03 01:26:35.952519+00	0	0	1906	1236	0	20	58	121	12	1	0	ok
3129	2026-08-03 01:27:35.951794+00	0	0	1906	1229	0	20	58	120	12	1	0	ok
3130	2026-08-03 01:28:35.952882+00	0	0	1906	1229	0	20	58	119	12	1	0	ok
3131	2026-08-03 01:29:35.953866+00	0	0	1906	1233	0	20	58	120	12	1	0	ok
3132	2026-08-03 01:30:35.953415+00	0	0	1906	1229	0	20	58	120	11	1	0	ok
3133	2026-08-03 01:31:35.9529+00	0.05	0	1906	1230	0	20	58	121	12	1	0	ok
3134	2026-08-03 01:32:35.952706+00	0.02	0	1906	1242	0	20	58	120	11	1	0	ok
3135	2026-08-03 01:33:35.952749+00	0	0	1906	1233	0	20	58	119	11	1	0	ok
3136	2026-08-03 01:34:35.953003+00	0	0	1906	1231	0	20	58	120	11	1	0	ok
3137	2026-08-03 01:35:35.956429+00	0	0	1906	1234	0	20	58	120	11	1	0	ok
3138	2026-08-03 01:36:35.954154+00	0	0	1906	1245	0	20	58	119	11	1	0	ok
3139	2026-08-03 01:37:35.955169+00	0	0	1906	1239	0	20	58	120	11	1	0	ok
3140	2026-08-03 01:38:35.955482+00	0	0	1906	1226	0	20	58	120	11	1	0	ok
3141	2026-08-03 01:39:35.957132+00	0	0	1906	1231	0	20	58	121	11	1	0	ok
3142	2026-08-03 01:40:35.957912+00	0	0.5	1906	1226	0	20	58	120	11	1	0	ok
3143	2026-08-03 01:41:35.957933+00	0	0	1906	1235	0	20	58	120	11	1	0	ok
3144	2026-08-03 01:42:35.960249+00	0	0	1906	1229	0	20	58	120	11	1	0	ok
3145	2026-08-03 01:43:35.960325+00	0	0	1906	1233	0	20	58	120	11	1	0	ok
3146	2026-08-03 01:44:35.960871+00	0	0	1906	1235	0	20	58	120	12	1	0	ok
3147	2026-08-03 01:45:35.962482+00	0	0	1906	1232	0	20	58	120	11	1	0	ok
3148	2026-08-03 01:46:35.961571+00	0	0.5	1906	1246	0	20	58	119	11	1	0	ok
3149	2026-08-03 01:47:35.962629+00	0	0	1906	1230	0	20	58	119	11	1	0	ok
3150	2026-08-03 01:48:35.962083+00	0	0	1906	1231	0	20	58	120	11	1	0	ok
3151	2026-08-03 01:49:35.963223+00	0	0	1906	1244	0	20	58	121	11	1	0	ok
3152	2026-08-03 01:50:35.963344+00	0	0	1906	1226	0	20	58	120	12	1	0	ok
3153	2026-08-03 01:51:35.963814+00	0	0	1906	1235	0	20	58	119	12	1	0	ok
3154	2026-08-03 01:52:35.965148+00	0	0	1906	1241	0	20	58	120	11	1	0	ok
3155	2026-08-03 01:53:35.964514+00	0	0	1906	1233	0	20	58	120	11	1	0	ok
3156	2026-08-03 01:54:35.965991+00	0	0	1906	1237	0	20	58	120	11	1	0	ok
3157	2026-08-03 01:55:35.967357+00	0	0	1906	1226	0	20	58	121	11	1	0	ok
3158	2026-08-03 01:56:35.969005+00	0	0	1906	1239	0	20	58	120	11	1	0	ok
3159	2026-08-03 01:57:35.965969+00	0	0	1906	1240	0	20	58	120	11	1	0	ok
3160	2026-08-03 01:58:35.967549+00	0	0	1906	1235	0	20	58	121	11	1	0	ok
3161	2026-08-03 01:59:35.968156+00	0	0.5	1906	1234	0	20	58	120	11	1	0	ok
3162	2026-08-03 02:00:35.969134+00	0	0	1906	1243	0	20	58	120	11	1	0	ok
3163	2026-08-03 02:01:35.970518+00	0	0	1906	1233	0	20	58	120	12	1	0	ok
3164	2026-08-03 02:02:35.970415+00	0	0	1906	1241	0	20	58	120	11	1	0	ok
3165	2026-08-03 02:03:35.970664+00	0.4	0	1906	1237	0	20	58	120	12	1	0	ok
3166	2026-08-03 02:04:35.971926+00	0.42	0	1906	1240	0	20	58	120	12	1	0	ok
3167	2026-08-03 02:05:35.973938+00	0.15	0.5	1906	1239	0	20	58	121	12	1	0	ok
3168	2026-08-03 02:06:35.974536+00	0.05	0	1906	1241	0	20	58	120	12	1	0	ok
3169	2026-08-03 02:07:35.975499+00	0.02	0	1906	1235	0	20	58	113	12	1	0	ok
3170	2026-08-03 02:08:35.977285+00	0.05	0.5	1906	1236	0	20	58	113	12	1	0	ok
3171	2026-08-03 02:09:35.984955+00	0.02	0	1906	1234	0	20	58	115	12	1	0	ok
3172	2026-08-03 02:10:35.984795+00	0	0	1906	1237	0	20	58	115	12	1	0	ok
3173	2026-08-03 02:11:35.980219+00	0	0	1906	1238	0	20	58	117	12	1	0	ok
3174	2026-08-03 02:12:35.979836+00	0	0	1906	1232	0	20	58	117	12	1	0	ok
3175	2026-08-03 02:13:35.97959+00	0	0	1906	1244	0	20	58	118	12	1	0	ok
3176	2026-08-03 02:14:35.98204+00	0	0	1906	1242	0	20	58	117	12	1	0	ok
3177	2026-08-03 02:15:35.983325+00	0	0	1906	1227	0	20	58	118	12	1	0	ok
3178	2026-08-03 02:16:35.982339+00	0	0	1906	1226	0	20	58	118	12	1	0	ok
3179	2026-08-03 02:17:35.984145+00	0.06	0	1906	1226	0	20	58	118	12	1	0	ok
3180	2026-08-03 02:18:35.984472+00	0.02	0	1906	1237	0	20	58	118	12	1	0	ok
3181	2026-08-03 02:19:35.986926+00	0.07	0	1906	1246	0	20	58	118	12	1	0	ok
3182	2026-08-03 02:20:35.986556+00	0.02	0	1906	1231	0	20	58	118	12	1	0	ok
3183	2026-08-03 02:21:35.9885+00	0.13	0	1906	1235	0	20	58	119	12	1	0	ok
3184	2026-08-03 02:22:35.987597+00	0.05	0	1906	1242	0	20	58	118	12	1	0	ok
3185	2026-08-03 02:23:35.986558+00	0.46	0	1906	1229	0	20	58	119	12	1	0	ok
3186	2026-08-03 02:24:35.987658+00	0.17	0	1906	1229	0	20	58	118	12	1	0	ok
3187	2026-08-03 02:25:35.989494+00	0.06	0	1906	1240	0	20	58	118	12	1	0	ok
3188	2026-08-03 02:26:35.988314+00	0.02	0	1906	1241	0	20	58	118	12	1	0	ok
3189	2026-08-03 02:27:35.988077+00	0.01	0	1906	1232	0	20	58	118	12	1	0	ok
3190	2026-08-03 02:28:35.988699+00	0.08	0	1906	1245	0	20	58	118	12	1	0	ok
3191	2026-08-03 02:29:35.988317+00	0.12	0	1906	1229	0	20	58	118	12	1	0	ok
3192	2026-08-03 02:30:35.989104+00	0.25	0	1906	1235	0	20	58	118	12	1	0	ok
3193	2026-08-03 02:31:35.992484+00	0.09	0	1906	1226	0	20	58	118	11	1	0	ok
3194	2026-08-03 02:32:35.989894+00	0.03	0	1906	1228	0	20	58	119	11	1	0	ok
3195	2026-08-03 02:33:35.989404+00	0.01	0	1906	1239	0	20	58	119	11	1	0	ok
3196	2026-08-03 02:34:35.989967+00	0	0	1906	1229	0	20	58	119	10	1	0	ok
3197	2026-08-03 02:35:35.990381+00	0	0	1906	1239	0	20	58	118	10	1	0	ok
3198	2026-08-03 02:36:35.990426+00	0	0	1906	1234	0	20	58	118	11	1	0	ok
3199	2026-08-03 02:37:35.990487+00	0	0	1906	1246	0	20	58	118	11	1	0	ok
3200	2026-08-03 02:38:35.992102+00	0	0	1906	1229	0	20	58	118	10	1	0	ok
3201	2026-08-03 02:39:35.991119+00	0.06	0	1906	1236	0	20	58	118	10	1	0	ok
3202	2026-08-03 02:40:35.992788+00	0.06	0	1906	1234	0	20	58	118	10	1	0	ok
3203	2026-08-03 02:41:35.991463+00	0.02	0	1906	1242	0	20	58	119	10	1	0	ok
3204	2026-08-03 02:42:35.992159+00	0.01	0	1906	1236	0	20	58	118	10	1	0	ok
3205	2026-08-03 02:43:35.993588+00	0	0	1906	1228	0	20	58	120	10	1	0	ok
3206	2026-08-03 02:44:35.991768+00	0	0.5	1906	1232	0	20	58	119	11	1	0	ok
3207	2026-08-03 02:45:35.992482+00	0	0	1906	1242	0	20	58	120	10	1	0	ok
3208	2026-08-03 02:46:35.993081+00	0	0	1906	1226	0	20	58	118	10	1	0	ok
3209	2026-08-03 02:47:35.991711+00	0	0	1906	1234	0	20	58	119	10	1	0	ok
3210	2026-08-03 02:48:35.994099+00	0	0	1906	1233	0	20	58	118	11	1	0	ok
3211	2026-08-03 02:49:35.995153+00	0	0	1906	1233	0	20	58	120	11	1	0	ok
3212	2026-08-03 02:50:35.995869+00	0.04	0	1906	1234	0	20	58	119	11	1	0	ok
3213	2026-08-03 02:51:35.996486+00	0.14	0	1906	1228	0	20	58	119	11	1	0	ok
3214	2026-08-03 02:52:35.99635+00	0.05	0	1906	1236	0	20	58	119	11	1	0	ok
3215	2026-08-03 02:53:35.996979+00	0.11	0	1906	1245	0	20	58	118	11	1	0	ok
3216	2026-08-03 02:54:35.998389+00	0.04	0	1906	1243	0	20	58	119	11	1	0	ok
3217	2026-08-03 02:55:35.998172+00	0.13	0	1906	1229	0	20	58	119	11	1	0	ok
3218	2026-08-03 02:56:35.999627+00	0.09	0	1906	1233	0	20	58	119	11	1	0	ok
3219	2026-08-03 02:57:35.998945+00	0.03	0	1906	1244	0	20	58	118	11	1	0	ok
3220	2026-08-03 02:58:36.000092+00	0.01	0	1906	1243	0	20	58	119	11	1	0	ok
3221	2026-08-03 02:59:36.001502+00	0	0	1906	1247	0	20	58	119	11	1	0	ok
3222	2026-08-03 03:00:36.001777+00	0	0	1906	1235	0	20	58	120	11	1	0	ok
3223	2026-08-03 03:01:36.001524+00	0	0	1906	1241	0	20	58	120	11	1	0	ok
3224	2026-08-03 03:02:36.00138+00	0	0	1906	1239	0	20	58	119	11	1	0	ok
3225	2026-08-03 03:03:36.002119+00	0	0	1906	1227	0	20	58	119	11	1	0	ok
3226	2026-08-03 03:04:36.002894+00	0	0	1906	1226	0	20	58	120	11	1	0	ok
3227	2026-08-03 03:05:36.002521+00	0	0	1906	1238	0	20	58	119	10	1	0	ok
3228	2026-08-03 03:06:36.002048+00	0	0	1906	1234	0	20	58	119	10	1	0	ok
3229	2026-08-03 03:07:36.003192+00	0	0	1906	1234	0	20	58	120	10	1	0	ok
3230	2026-08-03 03:08:36.005123+00	0	0	1906	1230	0	20	58	119	11	1	0	ok
3231	2026-08-03 03:09:36.00641+00	0	0	1906	1235	0	20	58	119	11	1	0	ok
3232	2026-08-03 03:10:36.005873+00	0.22	0	1906	1237	0	20	58	120	11	1	0	ok
3233	2026-08-03 03:11:36.005771+00	0.3	0	1906	1246	0	20	58	120	11	1	0	ok
3234	2026-08-03 03:12:36.00645+00	0.33	0	1906	1227	0	20	58	119	10	1	0	ok
3235	2026-08-03 03:13:36.005709+00	0.12	0	1906	1234	0	20	58	120	10	1	0	ok
3236	2026-08-03 03:14:36.007272+00	0.04	0	1906	1242	0	20	58	119	10	1	0	ok
3237	2026-08-03 03:15:36.008271+00	0.01	0.5	1906	1226	0	20	58	119	10	1	0	ok
3238	2026-08-03 03:16:36.00822+00	0	0.5	1906	1231	0	20	58	119	10	1	0	ok
3239	2026-08-03 03:17:36.010661+00	0	0	1906	1246	0	20	58	120	10	1	0	ok
3240	2026-08-03 03:18:36.009115+00	0	0	1906	1243	0	20	58	119	10	1	0	ok
3241	2026-08-03 03:19:36.011016+00	0	0	1906	1227	0	20	58	119	10	1	0	ok
3242	2026-08-03 03:20:36.011267+00	0	0	1906	1225	0	20	58	120	11	1	0	ok
3243	2026-08-03 03:21:36.012616+00	0	0	1906	1226	0	20	58	120	11	1	0	ok
3244	2026-08-03 03:22:36.014485+00	0	0	1906	1225	0	20	58	119	11	1	0	ok
3245	2026-08-03 03:23:36.014148+00	0	0	1906	1228	0	20	58	120	12	1	0	ok
3246	2026-08-03 03:24:36.015515+00	0.12	0	1906	1226	0	20	58	120	12	1	0	ok
3247	2026-08-03 03:25:36.019516+00	0.1	0	1906	1241	0	20	58	120	12	1	0	ok
3248	2026-08-03 03:26:36.019076+00	0.04	0	1906	1230	0	20	58	120	12	1	0	ok
3249	2026-08-03 03:27:36.020534+00	0.01	0	1906	1242	0	20	58	119	11	1	0	ok
3250	2026-08-03 03:28:36.019375+00	0	0	1906	1241	0	20	58	120	11	1	0	ok
3251	2026-08-03 03:29:36.021548+00	0	0.49	1906	1244	0	20	58	120	11	1	0	ok
3252	2026-08-03 03:30:36.022034+00	0	0	1906	1227	0	20	58	120	11	1	0	ok
3253	2026-08-03 03:31:36.024384+00	0	0	1906	1226	0	20	58	120	11	1	0	ok
3254	2026-08-03 03:32:36.023425+00	0	0	1906	1234	0	20	58	120	11	1	0	ok
3255	2026-08-03 03:33:36.026138+00	0	0	1906	1238	0	20	58	120	11	1	0	ok
3256	2026-08-03 03:34:36.026887+00	0	0	1906	1232	0	20	58	119	11	1	0	ok
3257	2026-08-03 03:35:36.026986+00	0.03	0	1906	1234	0	20	58	120	11	1	0	ok
3258	2026-08-03 03:36:36.027591+00	0.04	0	1906	1240	0	20	58	121	11	1	0	ok
3259	2026-08-03 03:37:36.027826+00	0.01	0	1906	1228	0	20	58	119	11	1	0	ok
3260	2026-08-03 03:38:36.028214+00	0	0	1906	1227	0	20	58	120	12	1	0	ok
3261	2026-08-03 03:39:36.030514+00	0	0	1906	1227	0	20	58	120	12	1	0	ok
3262	2026-08-03 03:40:36.031714+00	0	0	1906	1227	0	20	58	120	12	1	0	ok
3263	2026-08-03 03:41:36.031272+00	0	0	1906	1227	0	20	58	120	11	1	0	ok
3264	2026-08-03 03:42:36.03096+00	0	0	1906	1233	0	20	58	120	11	1	0	ok
3265	2026-08-03 03:43:36.030969+00	0	0	1906	1234	0	20	58	120	11	1	0	ok
3266	2026-08-03 03:44:36.034108+00	0	0	1906	1245	0	20	58	120	11	1	0	ok
3267	2026-08-03 03:45:36.032188+00	0	0	1906	1246	0	20	58	120	11	1	0	ok
3268	2026-08-03 03:46:36.032263+00	0	0	1906	1237	0	20	58	119	11	1	0	ok
3269	2026-08-03 03:47:36.033225+00	0	0	1906	1241	0	20	58	120	11	1	0	ok
3270	2026-08-03 03:48:36.033859+00	0	0	1906	1244	0	20	58	120	10	1	0	ok
3271	2026-08-03 03:49:36.031914+00	0	0	1906	1239	0	20	58	121	10	1	0	ok
3272	2026-08-03 03:50:36.031699+00	0	0	1906	1236	0	20	58	119	11	1	0	ok
3273	2026-08-03 03:51:36.033133+00	0	0	1906	1225	0	20	58	120	11	1	0	ok
3274	2026-08-03 03:52:36.033783+00	0	0	1906	1236	0	20	58	120	11	1	0	ok
3275	2026-08-03 03:53:36.033759+00	0	0	1906	1232	0	20	58	121	11	1	0	ok
3276	2026-08-03 03:54:36.033534+00	0.24	0	1906	1241	0	20	58	120	11	1	0	ok
3277	2026-08-03 03:55:36.03414+00	0.09	0	1906	1228	0	20	58	120	12	1	0	ok
3278	2026-08-03 03:56:36.034795+00	0.03	0	1906	1244	0	20	58	119	12	1	0	ok
3279	2026-08-03 03:57:36.038047+00	0.49	0	1906	1245	0	20	58	121	12	1	0	ok
3280	2026-08-03 03:58:36.035745+00	0.18	0	1906	1232	0	20	58	121	12	1	0	ok
3281	2026-08-03 03:59:36.035791+00	0.06	0	1906	1227	0	20	58	121	12	1	0	ok
3282	2026-08-03 04:00:36.035181+00	0.02	0.5	1906	1235	0	20	58	121	12	1	0	ok
3283	2026-08-03 04:01:36.034907+00	0.01	0	1906	1226	0	20	58	120	12	1	0	ok
3284	2026-08-03 04:02:36.03309+00	0	0	1906	1226	0	20	58	120	11	1	0	ok
3285	2026-08-03 04:03:36.034785+00	0	0	1906	1230	0	20	58	120	10	1	0	ok
3286	2026-08-03 04:04:36.034757+00	0	0	1906	1225	0	20	58	121	10	1	0	ok
3287	2026-08-03 04:05:36.037317+00	0	0.5	1906	1241	0	20	58	120	10	1	0	ok
3288	2026-08-03 04:06:36.035184+00	0	0	1906	1238	0	20	58	120	11	1	0	ok
3289	2026-08-03 04:07:36.035456+00	0	0	1906	1233	0	20	58	121	10	1	0	ok
3290	2026-08-03 04:08:36.036226+00	0	0	1906	1242	0	20	58	121	11	1	0	ok
3291	2026-08-03 04:09:36.037153+00	0	0	1906	1244	0	20	58	121	11	1	0	ok
3292	2026-08-03 04:10:36.037479+00	0	0	1906	1237	0	20	58	120	11	1	0	ok
3293	2026-08-03 04:11:36.038122+00	0	0	1906	1228	0	20	58	121	12	1	0	ok
3294	2026-08-03 04:12:36.038693+00	0.11	0	1906	1225	0	20	58	121	12	1	0	ok
3295	2026-08-03 04:13:36.040133+00	0.04	0	1906	1226	0	20	58	120	12	1	0	ok
3296	2026-08-03 04:14:36.039919+00	0.01	0	1906	1233	0	20	58	120	12	1	0	ok
3297	2026-08-03 04:15:36.039827+00	0.07	0	1906	1232	0	20	58	121	12	1	0	ok
3298	2026-08-03 04:16:36.039435+00	0.02	0	1906	1227	0	20	58	120	12	1	0	ok
3299	2026-08-03 04:17:36.039879+00	0.01	0	1906	1228	0	20	58	120	12	1	0	ok
3300	2026-08-03 04:18:36.040709+00	0	0	1906	1232	0	20	58	120	12	1	0	ok
3301	2026-08-03 04:19:36.04023+00	0	0	1906	1233	0	20	58	120	12	1	0	ok
3302	2026-08-03 04:20:36.045336+00	0	0	1906	1232	0	20	58	121	12	1	0	ok
3303	2026-08-03 04:21:36.040367+00	0.29	0	1906	1231	0	20	58	120	11	1	0	ok
3304	2026-08-03 04:22:36.040488+00	0.1	0	1906	1227	0	20	58	120	10	1	0	ok
3305	2026-08-03 04:23:36.041522+00	0.47	0	1906	1231	0	20	58	121	10	1	0	ok
3306	2026-08-03 04:24:36.041966+00	0.41	0	1906	1231	0	20	58	120	10	1	0	ok
3307	2026-08-03 04:25:36.042104+00	0.15	0	1906	1231	0	20	58	120	10	1	0	ok
3308	2026-08-03 04:26:36.0429+00	0.3	0	1906	1224	0	20	58	120	10	1	0	ok
3309	2026-08-03 04:27:36.043127+00	0.35	0	1906	1227	0	20	58	121	10	1	0	ok
3310	2026-08-03 04:28:36.042859+00	0.37	0	1906	1241	0	20	58	121	10	1	0	ok
3311	2026-08-03 04:29:36.044122+00	0.38	0	1906	1242	0	20	58	120	11	1	0	ok
3312	2026-08-03 04:30:36.045728+00	0.62	0	1906	1236	0	20	58	120	11	1	0	ok
3313	2026-08-03 04:31:36.049648+00	0.47	0	1906	1225	0	20	58	121	10	1	0	ok
3314	2026-08-03 04:32:36.046756+00	0.41	0	1906	1228	0	20	58	121	10	1	0	ok
3315	2026-08-03 04:33:36.046634+00	0.15	0	1906	1234	0	20	58	121	10	1	0	ok
3316	2026-08-03 04:34:36.046807+00	0.3	0	1906	1227	0	20	58	120	10	1	0	ok
3317	2026-08-03 04:35:36.047929+00	0.5	0	1906	1240	0	20	58	120	10	1	0	ok
3318	2026-08-03 04:36:36.04995+00	0.47	0	1906	1244	0	20	58	120	10	1	0	ok
3319	2026-08-03 04:37:36.049751+00	0.46	0	1906	1233	0	20	58	121	10	1	0	ok
3320	2026-08-03 04:38:36.051039+00	0.36	0	1906	1227	0	20	58	120	11	1	0	ok
3321	2026-08-03 04:39:36.053315+00	0.23	0	1906	1232	0	20	58	120	11	1	0	ok
3322	2026-08-03 04:40:36.051831+00	0.08	0.5	1906	1235	0	20	58	121	11	1	0	ok
3323	2026-08-03 04:41:36.05176+00	0.03	0	1906	1225	0	20	58	121	11	1	0	ok
3324	2026-08-03 04:42:36.054333+00	0.01	0	1906	1251	0	20	58	120	11	1	0	ok
3325	2026-08-03 04:43:36.055357+00	0	0	1906	1227	0	20	58	120	11	1	0	ok
3326	2026-08-03 04:44:36.056115+00	0.39	0	1906	1225	0	20	58	120	11	1	0	ok
3327	2026-08-03 04:45:36.05743+00	0.53	0	1906	1231	0	20	58	121	11	1	0	ok
3328	2026-08-03 04:46:36.059213+00	0.24	0	1906	1230	0	20	58	120	11	1	0	ok
3329	2026-08-03 04:47:36.057946+00	0.09	0	1906	1240	0	20	58	120	11	1	0	ok
3330	2026-08-03 04:48:36.060079+00	0.27	0	1906	1227	0	20	58	121	10	1	0	ok
3331	2026-08-03 04:49:36.060937+00	0.39	0	1906	1227	0	20	58	121	10	1	0	ok
3332	2026-08-03 04:50:36.062491+00	0.38	0	1906	1234	0	20	58	120	11	1	0	ok
3333	2026-08-03 04:51:36.063351+00	0.28	0	1906	1225	0	20	58	121	11	1	0	ok
3334	2026-08-03 04:52:36.064589+00	0.35	0	1906	1230	0	20	58	121	11	1	0	ok
3335	2026-08-03 04:53:36.065772+00	0.42	0	1906	1233	0	20	58	120	11	1	0	ok
3336	2026-08-03 04:54:36.065332+00	0.61	0	1906	1227	0	20	58	120	11	1	0	ok
3337	2026-08-03 04:55:36.066272+00	0.46	0	1906	1245	0	20	58	121	11	1	0	ok
3338	2026-08-03 04:56:36.066974+00	0.56	0	1906	1236	0	20	58	120	11	1	0	ok
3339	2026-08-03 04:57:36.069236+00	0.2	0	1906	1245	0	20	58	120	11	1	0	ok
3340	2026-08-03 04:58:36.068561+00	0.27	0	1906	1227	0	20	58	120	11	1	0	ok
3341	2026-08-03 04:59:36.067482+00	0.34	0	1906	1244	0	20	58	120	11	1	0	ok
3342	2026-08-03 05:00:36.071625+00	0.41	0	1906	1231	0	20	58	120	11	1	0	ok
3343	2026-08-03 05:01:36.069297+00	0.39	0	1906	1228	0	20	58	121	11	1	0	ok
3344	2026-08-03 05:02:36.070285+00	0.14	0	1906	1236	0	20	58	121	11	1	0	ok
3345	2026-08-03 05:03:36.07038+00	0.2	0	1906	1228	0	20	58	121	11	1	0	ok
3346	2026-08-03 05:04:36.070379+00	0.2	0	1906	1240	0	20	58	120	11	1	0	ok
3347	2026-08-03 05:05:36.0714+00	0.17	0	1906	1235	0	20	58	121	11	1	0	ok
3348	2026-08-03 05:06:36.070589+00	0.4	0	1906	1236	0	20	58	120	10	1	0	ok
3349	2026-08-03 05:07:36.071001+00	0.39	0	1906	1246	0	20	58	121	10	1	0	ok
3350	2026-08-03 05:08:36.070362+00	0.34	0	1906	1243	0	20	58	120	10	1	0	ok
3351	2026-08-03 05:09:36.070122+00	0.12	0	1906	1229	0	20	58	120	10	1	0	ok
3352	2026-08-03 05:10:36.070189+00	0.43	0	1906	1236	0	20	58	120	10	1	0	ok
3353	2026-08-03 05:11:36.074767+00	0.3	0	1906	1227	0	20	58	121	10	1	0	ok
3354	2026-08-03 05:12:36.070555+00	0.57	0	1906	1226	0	20	58	120	10	1	0	ok
3355	2026-08-03 05:13:36.070621+00	0.55	0.5	1906	1231	0	20	58	121	10	1	0	ok
3356	2026-08-03 05:14:36.073838+00	0.44	0	1906	1228	0	20	58	120	10	1	0	ok
3357	2026-08-03 05:15:36.07328+00	0.45	0	1906	1238	0	20	58	121	10	1	0	ok
3358	2026-08-03 05:16:36.07297+00	0.16	0	1906	1244	0	20	58	120	10	1	0	ok
3359	2026-08-03 05:17:36.075127+00	0.06	0	1906	1237	0	20	58	121	10	1	0	ok
3360	2026-08-03 05:18:36.074555+00	0.34	0	1906	1232	0	20	58	120	10	1	0	ok
3361	2026-08-03 05:19:36.07468+00	0.27	0	1906	1234	0	20	58	121	10	1	0	ok
3362	2026-08-03 05:20:36.074929+00	0.39	0	1906	1227	0	20	58	120	10	1	0	ok
3363	2026-08-03 05:21:36.075227+00	0.14	0	1906	1236	0	20	58	120	11	1	0	ok
3364	2026-08-03 05:22:36.076551+00	0.29	0	1906	1237	0	20	58	120	10	1	0	ok
3365	2026-08-03 05:23:36.077483+00	0.15	0	1906	1225	0	20	58	121	10	1	0	ok
3366	2026-08-03 05:24:36.078338+00	0.15	0	1906	1226	0	20	58	122	10	1	0	ok
3367	2026-08-03 05:25:36.078897+00	0.1	0	1906	1239	0	20	58	121	10	1	0	ok
3368	2026-08-03 05:26:36.078837+00	0.04	0	1906	1235	0	20	58	120	10	1	0	ok
3369	2026-08-03 05:27:36.078825+00	0.01	0	1906	1229	0	20	58	121	10	1	0	ok
3370	2026-08-03 05:28:36.079809+00	0.2	0	1906	1243	0	20	58	120	10	1	0	ok
3371	2026-08-03 05:29:36.079884+00	0.26	0	1906	1228	0	20	58	121	10	1	0	ok
3372	2026-08-03 05:30:36.082702+00	0.44	0	1906	1243	0	20	58	120	10	1	0	ok
3373	2026-08-03 05:31:36.079776+00	0.16	0	1906	1225	0	20	58	121	10	1	0	ok
3374	2026-08-03 05:32:36.081746+00	0.2	0	1906	1246	0	20	58	121	10	1	0	ok
3375	2026-08-03 05:33:36.080655+00	0.07	0	1906	1226	0	20	58	121	10	1	0	ok
3376	2026-08-03 05:34:36.079958+00	0.02	0	1906	1233	0	20	58	120	10	1	0	ok
3377	2026-08-03 05:35:36.080015+00	0.01	0	1906	1238	0	20	58	121	10	1	0	ok
3378	2026-08-03 05:36:36.083069+00	0.1	0	1906	1233	0	20	58	121	11	1	0	ok
3379	2026-08-03 05:37:36.083394+00	0.03	0	1906	1233	0	20	58	121	10	1	0	ok
3380	2026-08-03 05:38:36.082074+00	0.01	0	1906	1237	0	20	58	121	10	1	0	ok
3381	2026-08-03 05:39:36.081782+00	0	0	1906	1227	0	20	58	121	10	1	0	ok
3382	2026-08-03 05:40:36.083037+00	0.1	0	1906	1229	0	20	58	121	10	1	0	ok
3383	2026-08-03 05:41:36.080969+00	0.18	0	1906	1232	0	20	58	121	10	1	0	ok
3384	2026-08-03 05:42:36.082314+00	0.31	0	1906	1224	0	20	58	120	10	1	0	ok
3385	2026-08-03 05:43:36.083459+00	0.11	0	1906	1241	0	20	58	121	11	1	0	ok
3386	2026-08-03 05:44:36.081821+00	0.36	0	1906	1243	0	20	58	121	11	1	0	ok
3387	2026-08-03 05:45:36.082669+00	0.33	0	1906	1237	0	20	58	120	11	1	0	ok
3388	2026-08-03 05:46:36.083743+00	0.17	0.5	1906	1225	0	20	58	120	11	1	0	ok
3389	2026-08-03 05:47:36.083944+00	0.06	0	1906	1224	0	20	58	121	11	1	0	ok
3390	2026-08-03 05:48:36.083569+00	0.32	0	1906	1228	0	20	58	120	10	1	0	ok
3391	2026-08-03 05:49:36.083372+00	0.12	0	1906	1232	0	20	58	122	10	1	0	ok
3392	2026-08-03 05:50:36.083387+00	0.24	0	1906	1243	0	20	58	121	10	1	0	ok
3393	2026-08-03 05:51:36.082041+00	0.08	0	1906	1224	0	20	58	121	10	1	0	ok
3394	2026-08-03 05:52:36.081793+00	0.11	0	1906	1236	0	20	58	121	10	1	0	ok
3395	2026-08-03 05:53:36.082508+00	0.04	0	1906	1228	0	20	58	121	10	1	0	ok
3396	2026-08-03 05:54:36.083852+00	0.01	0	1906	1224	0	20	58	121	11	1	0	ok
3397	2026-08-03 05:55:36.083433+00	0.07	0	1906	1240	0	20	58	121	11	1	0	ok
3398	2026-08-03 05:56:36.084586+00	0.02	0	1906	1238	0	20	58	121	11	1	0	ok
3399	2026-08-03 05:57:36.084358+00	0.01	0	1906	1245	0	20	58	121	11	1	0	ok
3400	2026-08-03 05:58:36.08565+00	0	0	1906	1234	0	20	58	121	11	1	0	ok
3401	2026-08-03 05:59:36.085777+00	0.05	0	1906	1225	0	20	58	121	11	1	0	ok
3402	2026-08-03 06:00:36.08815+00	0.02	0	1906	1244	0	20	58	121	10	1	0	ok
3403	2026-08-03 06:01:36.087859+00	0	0	1906	1226	0	20	58	121	11	1	0	ok
3404	2026-08-03 06:02:36.087805+00	0	0	1906	1242	0	20	58	121	11	1	0	ok
3405	2026-08-03 06:03:36.089278+00	0	0	1906	1226	0	20	58	121	11	1	0	ok
3406	2026-08-03 06:04:36.087676+00	0	0	1906	1244	0	20	58	122	11	1	0	ok
3407	2026-08-03 06:05:36.089979+00	0	0	1906	1240	0	20	58	120	12	1	0	ok
3408	2026-08-03 06:06:36.089687+00	0	0	1906	1235	0	20	58	121	11	1	0	ok
3409	2026-08-03 06:07:36.09077+00	0	0	1906	1228	0	20	58	120	11	1	0	ok
3410	2026-08-03 06:08:36.091266+00	0	0	1906	1225	0	20	58	121	11	1	0	ok
3411	2026-08-03 06:09:36.090831+00	0.05	0	1906	1231	0	20	58	122	11	1	0	ok
3412	2026-08-03 06:10:36.092987+00	0.02	0	1906	1229	0	20	58	121	11	1	0	ok
3413	2026-08-03 06:11:36.093988+00	0.13	0	1906	1240	0	20	58	121	11	1	0	ok
3414	2026-08-03 06:12:36.092623+00	0.04	0	1906	1227	0	20	58	122	11	1	0	ok
3415	2026-08-03 06:13:36.09519+00	0.01	0	1906	1226	0	20	58	121	12	1	0	ok
3416	2026-08-03 06:14:36.096076+00	0.07	0	1906	1242	0	20	58	121	11	1	0	ok
3417	2026-08-03 06:15:36.098328+00	0.07	0.5	1906	1236	0	20	58	121	12	1	0	ok
3418	2026-08-03 06:16:36.097702+00	0.02	0	1906	1240	0	20	58	121	12	1	0	ok
3419	2026-08-03 06:17:36.097693+00	0.01	0	1906	1237	0	20	58	121	12	1	0	ok
3420	2026-08-03 06:18:36.099881+00	0	0	1906	1232	0	20	58	121	12	1	0	ok
3421	2026-08-03 06:19:36.101189+00	0	0	1906	1223	0	20	58	122	12	1	0	ok
3422	2026-08-03 06:20:36.099768+00	0	0	1906	1223	0	20	58	122	12	1	0	ok
3423	2026-08-03 06:21:36.100247+00	0	0	1906	1228	0	20	58	122	12	1	0	ok
3424	2026-08-03 06:22:36.099911+00	0.03	0	1906	1239	0	20	58	121	11	1	0	ok
3425	2026-08-03 06:23:36.100297+00	0.01	0	1906	1226	0	20	58	121	11	1	0	ok
3426	2026-08-03 06:24:36.100692+00	0	0	1906	1235	0	20	58	121	11	1	0	ok
3427	2026-08-03 06:25:36.115259+00	0	0	1906	1238	0	20	58	121	11	1	0	ok
3428	2026-08-03 06:26:36.101694+00	0	0	1906	1237	0	20	58	121	10	1	0	ok
3429	2026-08-03 06:27:36.101116+00	0	0	1906	1231	0	20	58	121	10	1	0	ok
3430	2026-08-03 06:28:36.100237+00	0	0	1906	1243	0	20	58	121	10	1	0	ok
3431	2026-08-03 06:29:36.100653+00	0	0	1906	1241	0	20	58	122	10	1	0	ok
3432	2026-08-03 06:30:36.10039+00	0	0	1906	1224	0	20	58	121	10	1	0	ok
3433	2026-08-03 06:31:36.101612+00	0	0	1906	1232	0	20	58	121	10	1	0	ok
3434	2026-08-03 06:32:36.100928+00	0	0	1906	1234	0	20	58	121	9	1	0	ok
3435	2026-08-03 06:33:36.101108+00	0	0	1906	1233	0	20	58	122	11	1	0	ok
3436	2026-08-03 06:34:36.099493+00	0	0	1906	1239	0	20	58	122	10	1	0	ok
3437	2026-08-03 06:35:36.100292+00	0	0	1906	1233	0	20	58	121	10	1	0	ok
3438	2026-08-03 06:36:36.100307+00	0.12	0	1906	1233	0	20	58	121	10	1	0	ok
3439	2026-08-03 06:37:36.099797+00	0.04	0	1906	1241	0	20	58	122	10	1	0	ok
3440	2026-08-03 06:38:36.101298+00	0.01	0	1906	1243	0	20	58	122	10	1	0	ok
3441	2026-08-03 06:39:36.100224+00	0	0	1906	1229	0	20	58	121	10	1	0	ok
3442	2026-08-03 06:40:36.100936+00	0.06	0	1906	1226	0	20	58	121	10	1	0	ok
3443	2026-08-03 06:41:36.100454+00	0.02	0	1906	1232	0	20	58	122	10	1	0	ok
3444	2026-08-03 06:42:36.101644+00	0	0	1906	1238	0	20	58	121	10	1	0	ok
3445	2026-08-03 06:43:36.101344+00	0	0	1906	1236	0	20	58	121	11	1	0	ok
3446	2026-08-03 06:44:36.10258+00	0	0	1906	1240	0	20	58	122	11	1	0	ok
3447	2026-08-03 06:45:36.102503+00	0	0	1906	1241	0	20	58	122	11	1	0	ok
3448	2026-08-03 06:46:36.104657+00	0	0	1906	1237	0	20	58	121	11	1	0	ok
3449	2026-08-03 06:47:36.104016+00	0	0	1906	1227	0	20	58	121	10	1	0	ok
3450	2026-08-03 06:48:36.105159+00	0	0	1906	1239	0	20	58	121	11	1	0	ok
3451	2026-08-03 06:49:36.106165+00	0	0	1906	1230	0	20	58	122	10	1	0	ok
3452	2026-08-03 06:50:36.107982+00	0	0	1906	1232	0	20	58	122	12	1	0	ok
3453	2026-08-03 06:51:36.107292+00	0	0	1906	1235	0	20	58	121	12	1	0	ok
3454	2026-08-03 06:52:36.107505+00	0	0	1906	1228	0	20	58	121	11	1	0	ok
3455	2026-08-03 06:53:36.110011+00	0	0	1906	1240	0	20	58	121	11	1	0	ok
3456	2026-08-03 06:54:36.11024+00	0	0	1906	1241	0	20	58	121	11	1	0	ok
3457	2026-08-03 06:55:36.109956+00	0	0	1906	1225	0	20	58	121	11	1	0	ok
3458	2026-08-03 06:56:36.110764+00	0	0	1906	1227	0	20	58	121	11	1	0	ok
3459	2026-08-03 06:57:36.115417+00	0	0	1906	1231	0	20	58	122	11	1	0	ok
3460	2026-08-03 06:58:36.112114+00	0	0	1906	1225	0	20	58	121	11	1	0	ok
3461	2026-08-03 06:59:36.11343+00	0	0	1906	1229	0	20	58	122	11	1	0	ok
3462	2026-08-03 07:00:36.113967+00	0	0	1906	1234	0	20	58	122	11	1	0	ok
3463	2026-08-03 07:01:36.114182+00	0	0	1906	1238	0	20	58	121	10	1	0	ok
3464	2026-08-03 07:02:36.117664+00	0	0.5	1906	1225	0	20	58	121	11	1	0	ok
3465	2026-08-03 07:03:36.115483+00	0	0	1906	1229	0	20	58	122	11	1	0	ok
3466	2026-08-03 07:04:36.11693+00	0	0	1906	1226	0	20	58	122	10	1	0	ok
3467	2026-08-03 07:05:36.116223+00	0	0.5	1906	1229	0	20	58	122	10	1	0	ok
3468	2026-08-03 07:06:36.117602+00	0	0	1906	1228	0	20	58	121	10	1	0	ok
3469	2026-08-03 07:07:36.117386+00	0	0.5	1906	1234	0	20	58	121	10	1	0	ok
3470	2026-08-03 07:08:36.118797+00	0	0	1906	1235	0	20	58	121	11	1	0	ok
3471	2026-08-03 07:09:36.118951+00	0	0	1906	1237	0	20	58	121	11	1	0	ok
3472	2026-08-03 07:10:36.120864+00	0	0	1906	1228	0	20	58	121	11	1	0	ok
3473	2026-08-03 07:11:36.119291+00	0	0	1906	1228	0	20	58	122	12	1	0	ok
3474	2026-08-03 07:12:36.119001+00	0	0	1906	1232	0	20	58	122	11	1	0	ok
3475	2026-08-03 07:13:36.119821+00	0	0	1906	1230	0	20	58	122	11	1	0	ok
3476	2026-08-03 07:14:36.120762+00	0	0.5	1906	1232	0	20	58	121	11	1	0	ok
3477	2026-08-03 07:15:36.121516+00	0	0.5	1906	1234	0	20	58	121	11	1	0	ok
3478	2026-08-03 07:16:36.122318+00	0	0	1906	1229	0	20	58	122	11	1	0	ok
3479	2026-08-03 07:17:36.121909+00	0	0	1906	1227	0	20	58	121	11	1	0	ok
3480	2026-08-03 07:18:36.124625+00	0	0.5	1906	1229	0	20	58	121	11	1	0	ok
3481	2026-08-03 07:19:36.122495+00	0	0	1906	1232	0	20	58	121	11	1	0	ok
3482	2026-08-03 07:20:36.124276+00	0	0	1906	1230	0	20	58	122	11	1	0	ok
3483	2026-08-03 07:21:36.125243+00	0	0	1906	1236	0	20	58	122	11	1	0	ok
3484	2026-08-03 07:22:36.125158+00	0	0	1906	1223	0	20	58	121	10	1	0	ok
3485	2026-08-03 07:23:36.126295+00	0	0	1906	1226	0	20	58	121	11	1	0	ok
3486	2026-08-03 07:24:36.127702+00	0.07	0.5	1906	1243	0	20	58	121	10	1	0	ok
3487	2026-08-03 07:25:36.128545+00	0.02	0	1906	1229	0	20	58	121	10	1	0	ok
3488	2026-08-03 07:26:36.129387+00	0.1	0	1906	1227	0	20	58	121	11	1	0	ok
3489	2026-08-03 07:27:36.129812+00	0.03	0	1906	1227	0	20	58	122	10	1	0	ok
3490	2026-08-03 07:28:36.131402+00	0.01	0	1906	1230	0	20	58	121	11	1	0	ok
3491	2026-08-03 07:29:36.132597+00	0	0	1906	1229	0	20	58	122	10	1	0	ok
3492	2026-08-03 07:30:36.134497+00	0	0	1906	1231	0	20	58	121	10	1	0	ok
3493	2026-08-03 07:31:36.13423+00	0	0	1906	1224	0	20	58	121	11	1	0	ok
3494	2026-08-03 07:32:36.134419+00	0	0	1906	1240	0	20	58	122	10	1	0	ok
3495	2026-08-03 07:33:36.135732+00	0	0	1906	1226	0	20	58	122	11	1	0	ok
3496	2026-08-03 07:34:36.135792+00	0	0	1906	1235	0	20	58	121	11	1	0	ok
3497	2026-08-03 07:35:36.138239+00	0	0	1906	1232	0	20	58	122	11	1	0	ok
3498	2026-08-03 07:36:36.137467+00	0	0	1906	1235	0	20	58	122	11	1	0	ok
3499	2026-08-03 07:37:36.139284+00	0	0	1906	1232	0	20	58	122	11	1	0	ok
3500	2026-08-03 07:38:36.138804+00	0	0	1906	1225	0	20	58	121	11	1	0	ok
3501	2026-08-03 07:39:36.138439+00	0	0	1906	1236	0	20	58	121	11	1	0	ok
3502	2026-08-03 07:40:36.138076+00	0	0	1906	1241	0	20	58	122	11	1	0	ok
3503	2026-08-03 07:41:36.139226+00	0	0	1906	1225	0	20	58	121	11	1	0	ok
3504	2026-08-03 07:42:36.141695+00	0	0	1906	1238	0	20	58	121	10	1	0	ok
3505	2026-08-03 07:43:36.140061+00	0	0	1906	1240	0	20	58	122	10	1	0	ok
3506	2026-08-03 07:44:36.139944+00	0	0	1906	1224	0	20	58	121	10	1	0	ok
3507	2026-08-03 07:45:36.141798+00	0	0	1906	1241	0	20	58	122	10	1	0	ok
3508	2026-08-03 07:46:36.140725+00	0	0	1906	1242	0	20	58	122	10	1	0	ok
3509	2026-08-03 07:47:36.140905+00	0	0	1906	1235	0	20	58	121	10	1	0	ok
3510	2026-08-03 07:48:36.14209+00	0	0.5	1906	1222	0	20	58	121	10	1	0	ok
3511	2026-08-03 07:49:36.144987+00	0	0	1906	1224	0	20	58	122	10	1	0	ok
3512	2026-08-03 07:50:36.144787+00	0	0.5	1906	1238	0	20	58	121	10	1	0	ok
3513	2026-08-03 07:51:36.144704+00	0	0	1906	1231	0	20	58	121	11	1	0	ok
3514	2026-08-03 07:52:36.147509+00	0	0	1906	1226	0	20	58	122	11	1	0	ok
3515	2026-08-03 07:53:36.144814+00	0	0	1906	1225	0	20	58	122	11	1	0	ok
3516	2026-08-03 07:54:36.144727+00	0	0	1906	1224	0	20	58	123	11	1	0	ok
3517	2026-08-03 07:55:36.145952+00	0	0	1906	1226	0	20	58	122	11	1	0	ok
3518	2026-08-03 07:56:36.148627+00	0	0	1906	1226	0	20	58	122	11	1	0	ok
3519	2026-08-03 07:57:36.147769+00	0	0	1906	1225	0	20	58	126	11	1	0	ok
3520	2026-08-03 07:58:36.147776+00	0	0	1906	1242	0	20	58	117	11	1	0	ok
3521	2026-08-03 07:59:36.14891+00	0	0.5	1906	1232	0	20	58	118	11	1	0	ok
3522	2026-08-03 08:00:36.147658+00	0	0	1906	1245	0	20	58	119	11	1	0	ok
3523	2026-08-03 08:01:36.149341+00	0	0.5	1906	1229	0	20	58	120	10	1	0	ok
3524	2026-08-03 08:02:36.148582+00	0	0	1906	1227	0	20	58	121	10	1	0	ok
3525	2026-08-03 08:03:36.148912+00	0	0.5	1906	1225	0	20	58	122	11	1	0	ok
3526	2026-08-03 08:04:36.149974+00	0	0.5	1906	1238	0	20	58	122	9	1	0	ok
3527	2026-08-03 08:05:36.151792+00	0	0	1906	1234	0	20	58	123	10	1	0	ok
3528	2026-08-03 08:06:36.151826+00	0	0	1906	1234	0	20	58	123	10	1	0	ok
3529	2026-08-03 08:07:36.15075+00	0	0.5	1906	1232	0	20	58	123	11	1	0	ok
3530	2026-08-03 08:08:36.152861+00	0.05	0	1906	1224	0	20	58	123	12	1	0	ok
3531	2026-08-03 08:09:36.151227+00	0.08	0	1906	1238	0	20	58	123	13	1	0	ok
3532	2026-08-03 08:10:36.151006+00	0.03	0	1906	1235	0	20	58	123	12	1	0	ok
3533	2026-08-03 08:11:36.152295+00	0.01	0	1906	1218	0	20	58	123	13	1	0	ok
3534	2026-08-03 08:12:36.153334+00	0	0.5	1906	1225	0	20	58	123	13	1	0	ok
3535	2026-08-03 08:13:36.154774+00	0	0.5	1906	1239	0	20	58	123	14	1	0	ok
3536	2026-08-03 08:14:36.152782+00	0	0	1906	1231	0	20	58	124	9	1	0	ok
3537	2026-08-03 08:15:36.15651+00	0.1	0	1906	1229	0	20	58	124	9	1	0	ok
3538	2026-08-03 08:16:36.156547+00	0.03	0.5	1906	1226	0	20	58	123	10	1	0	ok
3539	2026-08-03 08:17:36.157299+00	0.01	0	1906	1233	0	20	58	124	10	1	0	ok
3540	2026-08-03 08:18:36.156821+00	0	0	1906	1225	0	20	58	123	10	1	0	ok
3541	2026-08-03 08:19:36.159629+00	0	0	1906	1230	0	20	58	123	11	1	0	ok
3542	2026-08-03 08:20:36.156101+00	0.12	0	1906	1238	0	20	58	123	11	1	0	ok
3543	2026-08-03 08:21:36.155521+00	0.04	0	1906	1227	0	20	58	123	11	1	0	ok
3544	2026-08-03 08:22:36.157904+00	0.01	0	1906	1214	0	20	58	126	18	1	0	ok
3545	2026-08-03 08:23:36.156723+00	0.05	0.5	1906	1218	0	20	58	123	10	1	0	ok
3546	2026-08-03 08:24:36.157679+00	0.02	0	1906	1227	0	20	58	123	11	1	0	ok
3547	2026-08-03 08:25:36.157547+00	0	0	1906	1221	0	20	58	125	11	1	0	ok
3548	2026-08-03 08:26:36.157223+00	0	0	1906	1233	0	20	58	125	11	1	0	ok
3549	2026-08-03 08:27:36.16006+00	0	0	1906	1232	0	20	58	125	12	1	0	ok
3550	2026-08-03 08:28:36.157775+00	0	0	1906	1231	0	20	58	126	12	1	0	ok
3551	2026-08-03 08:29:36.159117+00	0	0	1906	1230	0	20	58	126	11	1	0	ok
3552	2026-08-03 08:30:36.158884+00	0	0	1906	1240	0	20	58	122	11	1	0	ok
3553	2026-08-03 08:31:36.159169+00	0	0	1906	1234	0	20	58	122	11	1	0	ok
3554	2026-08-03 08:32:36.157782+00	0	0	1906	1228	0	20	58	123	11	1	0	ok
3555	2026-08-03 08:33:36.159908+00	0	0	1906	1221	0	20	58	126	12	1	0	ok
3556	2026-08-03 08:34:36.160161+00	0	0	1906	1220	0	20	58	125	12	1	0	ok
3557	2026-08-03 08:35:36.16037+00	0	0.5	1906	1213	0	20	58	124	16	1	0	ok
3558	2026-08-03 08:36:36.161378+00	0	0	1906	1222	0	20	58	124	11	1	0	ok
3559	2026-08-03 08:37:36.161666+00	0	0	1906	1237	0	20	58	126	11	1	0	ok
3560	2026-08-03 08:38:36.160696+00	0	0	1906	1230	0	20	58	126	11	1	0	ok
3561	2026-08-03 08:39:36.16335+00	0	0.5	1906	1218	0	20	58	124	11	1	0	ok
3562	2026-08-03 08:40:36.163309+00	0	0	1906	1230	0	20	58	123	11	1	0	ok
3563	2026-08-03 08:41:36.165875+00	0	0	1906	1235	0	20	58	124	11	1	0	ok
3564	2026-08-03 08:42:36.164249+00	0	0	1906	1238	0	20	58	124	12	1	0	ok
3565	2026-08-03 08:43:36.164764+00	0	0	1906	1234	0	20	58	125	12	1	0	ok
3566	2026-08-03 08:44:36.166372+00	0	0.5	1906	1228	0	20	58	125	11	1	0	ok
3567	2026-08-03 08:45:36.16724+00	0.05	0	1906	1219	0	20	58	125	12	1	0	ok
3568	2026-08-03 08:46:36.168358+00	0.18	0	1906	1232	0	20	58	126	12	1	0	ok
3569	2026-08-03 08:47:36.170229+00	0.06	0	1906	1229	0	20	58	125	11	1	0	ok
3570	2026-08-03 08:48:36.169994+00	0.02	0	1906	1217	0	20	58	125	11	1	0	ok
3571	2026-08-03 08:49:36.172234+00	0.01	0	1906	1222	0	20	58	126	11	1	0	ok
3572	2026-08-03 08:50:36.204749+00	0	0	1906	1217	0	20	58	125	11	1	0	ok
3573	2026-08-03 08:51:36.17369+00	0	0	1906	1230	0	20	58	125	11	1	0	ok
3574	2026-08-03 08:52:36.172887+00	0	0	1906	1235	0	20	58	126	11	1	0	ok
3575	2026-08-03 08:53:36.172299+00	0	0	1906	1234	0	20	58	121	11	1	0	ok
3576	2026-08-03 08:54:36.171786+00	0	0	1906	1230	0	20	58	123	11	1	0	ok
3577	2026-08-03 08:55:36.174467+00	0	0.5	1906	1233	0	20	58	123	11	1	0	ok
3578	2026-08-03 08:56:36.174344+00	0	0	1906	1223	0	20	58	124	11	1	0	ok
3579	2026-08-03 08:57:36.177221+00	0	0	1906	1232	0	20	58	123	11	1	0	ok
3580	2026-08-03 08:58:36.176152+00	0	0	1906	1236	0	20	58	124	11	1	0	ok
3581	2026-08-03 08:59:36.176991+00	0	0	1906	1227	0	20	58	123	11	1	0	ok
3582	2026-08-03 09:00:36.178072+00	0	0	1906	1220	0	20	58	123	10	1	0	ok
3583	2026-08-03 09:01:36.179025+00	0	0	1906	1218	0	20	58	125	10	1	0	ok
3584	2026-08-03 09:02:36.179109+00	0	0	1906	1224	0	20	58	126	10	1	0	ok
3585	2026-08-03 09:03:36.180485+00	0	0	1906	1228	0	20	58	125	10	1	0	ok
3586	2026-08-03 09:04:36.178269+00	0	0	1906	1226	0	20	58	125	9	1	0	ok
3587	2026-08-03 09:05:36.180571+00	0	0	1906	1228	0	20	58	125	9	1	0	ok
3588	2026-08-03 09:06:36.181285+00	0	0	1906	1217	0	20	58	124	10	1	0	ok
3589	2026-08-03 09:07:36.182301+00	0	0.5	1906	1072	0	20	58	127	10	1	0	ok
3590	2026-08-03 09:08:36.182331+00	0.03	0	1906	1219	0	20	58	125	10	1	0	ok
3591	2026-08-03 09:09:36.183407+00	0.01	0	1906	1218	0	20	58	127	10	1	0	ok
3592	2026-08-03 09:10:36.182675+00	0	0	1906	1216	0	20	58	126	11	1	0	ok
3593	2026-08-03 09:11:36.182649+00	0	0	1906	1234	0	20	58	125	11	1	0	ok
3594	2026-08-03 09:12:36.182259+00	0.05	0.5	1906	1215	0	20	58	127	11	1	0	ok
3595	2026-08-03 09:13:36.182897+00	0.02	0	1906	1216	0	20	58	126	11	1	0	ok
3596	2026-08-03 09:14:36.183316+00	0	0	1906	1217	0	20	58	127	11	1	0	ok
3597	2026-08-03 09:15:05.023101+00	0	0.5	1906	1250	0	20	58	99	12	1	0	ok
3598	2026-08-03 09:16:05.020522+00	0	0	1906	1234	0	20	58	89	15	1	0	ok
3599	2026-08-03 09:17:05.023353+00	0.48	0	1906	1230	0	20	58	94	18	1	0	ok
3600	2026-08-03 09:18:05.023971+00	0.34	0	1906	1247	0	20	58	96	15	1	0	ok
3601	2026-08-03 09:18:33.332562+00	0.2	0	1906	1267	0	20	58	99	12	1	0	ok
3602	2026-08-03 09:19:33.335484+00	0.07	0	1906	1237	0	20	58	99	11	1	0	ok
3603	2026-08-03 09:20:33.337955+00	0.02	0	1906	1240	0	20	58	106	12	1	0	ok
3604	2026-08-03 09:21:33.337773+00	0.01	0.5	1906	1229	0	20	58	108	10	1	0	ok
3605	2026-08-03 09:22:33.340339+00	0.06	0	1906	1224	0	20	58	110	10	1	0	ok
3606	2026-08-03 09:23:33.339261+00	0.02	0	1906	1216	0	20	58	111	10	1	0	ok
3607	2026-08-03 09:24:33.337883+00	0.01	0	1906	1221	0	20	58	110	10	1	0	ok
3608	2026-08-03 09:25:33.342024+00	0.06	0	1906	1198	0	20	58	113	15	1	0	ok
3609	2026-08-03 09:26:33.340096+00	0.1	0	1906	1206	0	20	58	116	13	1	0	ok
3610	2026-08-03 09:27:33.341052+00	0.04	0	1906	1208	0	20	58	123	12	1	0	ok
3611	2026-08-03 09:28:33.340823+00	0.01	0	1906	1210	0	20	58	123	12	1	0	ok
3612	2026-08-03 09:29:33.342611+00	0	0	1906	1217	0	20	58	123	10	1	0	ok
3613	2026-08-03 09:30:33.340539+00	0	0	1906	1212	0	20	58	123	11	1	0	ok
3614	2026-08-03 09:31:33.341527+00	0	0	1906	1220	0	20	58	123	10	1	0	ok
3615	2026-08-03 09:32:33.341422+00	0	0	1906	1222	0	20	58	123	10	1	0	ok
3616	2026-08-03 09:33:33.341111+00	0	0.5	1906	1219	0	20	58	123	10	1	0	ok
3617	2026-08-03 09:34:33.341492+00	0	0	1906	1213	0	20	58	124	13	1	0	ok
3618	2026-08-03 09:35:33.342604+00	0	0	1906	1220	0	20	58	118	10	1	0	ok
3619	2026-08-03 09:36:33.344217+00	0	0.5	1906	1224	0	20	58	120	10	1	0	ok
3620	2026-08-03 09:37:33.341487+00	0	0	1906	1223	0	20	58	122	10	1	0	ok
3621	2026-08-03 09:38:33.349656+00	0	0	1906	1217	0	20	58	123	12	1	0	ok
3622	2026-08-03 09:39:33.342132+00	0	0	1906	1212	0	20	58	125	10	1	0	ok
3623	2026-08-03 09:40:33.346818+00	0	0	1906	1210	0	20	58	126	13	1	0	ok
3624	2026-08-03 09:41:33.348668+00	0	0	1906	1212	0	20	58	126	10	1	0	ok
3625	2026-08-03 09:42:33.347079+00	0	0	1906	1223	0	20	58	126	11	1	0	ok
3626	2026-08-03 09:43:33.34789+00	0	0	1906	1215	0	20	58	125	10	1	0	ok
3627	2026-08-03 09:44:33.348029+00	0	0	1906	1223	0	20	58	126	12	1	0	ok
3628	2026-08-03 09:45:33.349795+00	0	0	1906	1229	0	20	58	126	10	1	0	ok
3629	2026-08-03 09:46:20.820417+00	0	0	1906	1246	0	20	58	99	12	1	0	ok
3630	2026-08-03 09:47:20.821338+00	0	0	1906	1233	0	20	58	88	15	1	0	ok
3631	2026-08-03 09:48:20.821796+00	0	0	1906	1236	0	20	58	93	14	1	0	ok
3632	2026-08-03 09:49:20.823047+00	0	0	1906	1238	0	20	58	94	13	1	0	ok
3633	2026-08-03 09:50:20.82552+00	0	0	1906	1229	0	20	58	97	18	1	0	ok
3634	2026-08-03 09:51:20.82557+00	0	0	1906	1232	0	20	58	95	19	1	0	ok
3635	2026-08-03 09:52:20.826453+00	0	0.5	1906	1219	0	20	58	96	19	1	0	ok
3636	2026-08-03 09:53:20.825718+00	0.06	0	1906	1210	0	20	58	100	18	1	0	ok
3637	2026-08-03 09:54:20.824791+00	0.02	0	1906	1231	0	20	58	101	18	1	0	ok
3638	2026-08-03 09:55:20.825788+00	0.01	0	1906	1222	0	20	58	101	18	1	0	ok
3639	2026-08-03 09:56:20.825425+00	0	0	1906	1222	0	20	58	110	19	1	0	ok
3640	2026-08-03 09:57:20.824997+00	0	0	1906	1224	0	20	58	104	16	1	0	ok
3641	2026-08-03 09:58:20.827848+00	0.06	0.5	1906	1229	0	20	58	107	19	1	0	ok
3642	2026-08-03 09:59:20.824797+00	0.02	0	1906	1206	0	20	58	108	19	1	0	ok
3643	2026-08-03 10:00:20.825926+00	0.14	0	1906	1212	0	20	58	110	19	1	0	ok
3644	2026-08-03 10:01:20.825556+00	0.05	0	1906	1208	0	20	58	110	18	1	0	ok
3645	2026-08-03 10:02:20.829033+00	0.02	0	1906	1213	0	20	58	110	19	1	0	ok
3646	2026-08-03 10:03:20.825847+00	0	0	1906	1223	0	20	58	111	18	1	0	ok
3647	2026-08-03 10:04:20.828682+00	0.08	0	1906	1214	0	20	58	111	20	1	0	ok
3648	2026-08-03 10:05:20.828898+00	0.08	0	1906	1224	0	20	58	111	18	1	0	ok
3649	2026-08-03 10:06:20.830364+00	0.03	0	1906	1206	0	20	58	111	19	1	0	ok
3650	2026-08-03 10:07:20.830713+00	0.01	0	1906	1211	0	20	58	111	18	1	0	ok
3651	2026-08-03 10:08:20.831792+00	0	0	1906	1210	0	20	58	111	19	1	0	ok
3652	2026-08-03 10:09:03.742289+00	0.08	0	1906	1229	0	20	58	99	13	1	0	ok
3653	2026-08-03 10:10:03.745131+00	0.11	2.49	1906	1225	0	20	58	88	15	1	0	ok
3654	2026-08-03 10:11:04.794613+00	0.11	16.42	1906	1213	0	20	58	95	18	1	0	critical
3655	2026-08-03 10:12:04.77484+00	0.04	3.52	1906	1207	0	20	58	98	21	1	0	ok
3656	2026-08-03 10:12:12.907293+00	0.03	0	1906	1252	0	20	58	98	14	1	0	ok
3657	2026-08-03 10:13:12.904836+00	0.01	0	1906	1213	0	20	58	97	16	1	0	ok
3658	2026-08-03 10:14:12.907745+00	0.1	0	1906	1216	0	20	58	101	13	1	0	ok
3659	2026-08-03 10:15:12.909823+00	0.04	0	1906	1216	0	20	58	104	13	1	0	ok
3660	2026-08-03 10:16:12.910967+00	0.01	0	1906	1223	0	20	58	99	13	1	0	ok
3661	2026-08-03 10:17:12.913385+00	0.05	0	1906	1214	0	20	58	101	13	1	0	ok
3662	2026-08-03 10:18:12.912885+00	0.06	0	1906	1222	0	20	58	103	16	1	0	ok
3663	2026-08-03 10:19:12.911575+00	0.02	0	1906	1212	0	20	58	105	12	1	0	ok
3664	2026-08-03 10:20:12.911731+00	0.01	0	1906	1210	0	20	58	105	13	1	0	ok
3665	2026-08-03 10:21:12.911167+00	0	0	1906	1215	0	20	58	106	11	1	0	ok
3666	2026-08-03 10:22:12.913419+00	0	0	1906	1223	0	20	58	107	11	1	0	ok
3667	2026-08-03 10:23:12.913937+00	0	0.5	1906	1213	0	20	58	106	12	1	0	ok
3668	2026-08-03 10:24:12.912888+00	0	0	1906	1219	0	20	58	106	14	1	0	ok
3669	2026-08-03 10:25:12.91506+00	0	0	1906	1209	0	20	58	106	14	1	0	ok
3670	2026-08-03 10:26:12.914042+00	0	0	1906	1206	0	20	58	108	14	1	0	ok
3671	2026-08-03 10:27:12.914255+00	0.06	0	1906	1209	0	20	56	106	17	1	0	ok
3672	2026-08-03 10:28:12.913642+00	0.02	0	1906	1209	0	20	56	106	17	1	0	ok
3673	2026-08-03 10:29:12.913771+00	0	0	1906	1220	0	20	56	106	13	1	0	ok
3674	2026-08-03 10:30:12.915309+00	0	0	1906	1212	0	20	56	108	13	1	0	ok
3675	2026-08-03 10:31:12.915117+00	0	0	1906	1211	0	20	56	108	13	1	0	ok
3676	2026-08-03 10:32:12.915739+00	0	0	1906	1208	0	20	56	108	13	1	0	ok
3677	2026-08-03 10:33:12.917067+00	0	0	1906	1211	0	20	56	107	13	1	0	ok
3678	2026-08-03 10:34:12.915957+00	0.08	0	1906	1206	0	20	56	108	18	1	0	ok
3679	2026-08-03 10:35:12.917125+00	0.03	0	1906	1210	0	20	56	109	18	1	0	ok
3680	2026-08-03 10:36:12.917186+00	0.01	0	1906	1204	0	20	56	107	18	1	0	ok
3681	2026-08-03 10:37:12.918467+00	0	0	1906	1213	0	20	56	107	16	1	0	ok
3682	2026-08-03 10:38:12.917425+00	0	0	1906	1202	0	20	56	108	18	1	0	ok
3683	2026-08-03 10:39:12.916922+00	0	0	1906	1206	0	20	56	108	18	1	0	ok
3684	2026-08-03 10:40:12.916474+00	0	0	1906	1210	0	20	56	108	19	1	0	ok
3685	2026-08-03 10:41:12.918338+00	0.03	0	1906	1212	0	20	56	107	18	1	0	ok
3686	2026-08-03 10:41:39.741891+00	0.02	0	1906	1262	0	20	56	98	12	1	0	ok
3687	2026-08-03 10:42:39.744196+00	0.11	0	1906	1235	0	20	56	90	11	1	0	ok
3688	2026-08-03 10:43:39.743596+00	0.26	0	1906	1231	0	20	56	96	12	1	0	ok
3689	2026-08-03 10:44:39.74594+00	0.09	0.5	1906	1229	0	20	56	98	11	1	0	ok
3690	2026-08-03 10:45:39.745701+00	0.12	0	1906	1233	0	20	56	99	11	1	0	ok
3691	2026-08-03 10:46:39.749087+00	0.31	0	1906	1227	0	20	56	99	11	1	0	ok
3692	2026-08-03 10:47:39.747607+00	0.11	0	1906	1233	0	20	56	101	11	1	0	ok
3693	2026-08-03 10:48:39.748086+00	0.04	0	1906	1221	0	20	56	103	11	1	0	ok
3694	2026-08-03 10:49:39.748282+00	0.06	0	1906	1232	0	20	56	103	11	1	0	ok
3695	2026-08-03 10:50:39.748142+00	0.19	0	1906	1229	0	20	56	103	12	1	0	ok
3696	2026-08-03 10:51:39.75125+00	0.07	0	1906	1226	0	20	56	105	11	1	0	ok
3697	2026-08-03 10:52:39.748109+00	0.02	0	1906	1215	0	20	56	106	11	1	0	ok
3698	2026-08-03 10:53:39.752276+00	0.43	0	1906	1224	0	20	56	106	11	1	0	ok
3699	2026-08-03 10:54:39.751043+00	0.16	0	1906	1219	0	20	56	107	11	1	0	ok
3700	2026-08-03 10:55:39.752633+00	0.19	0	1906	1230	0	20	56	107	11	1	0	ok
3701	2026-08-03 10:56:39.751942+00	0.07	0	1906	1223	0	20	56	106	11	1	0	ok
3702	2026-08-03 10:57:39.753071+00	0.02	0	1906	1223	0	20	56	102	10	1	0	ok
3703	2026-08-03 10:58:39.751226+00	0.01	0	1906	1234	0	20	56	104	10	1	0	ok
3704	2026-08-03 10:59:39.785242+00	0.11	0	1906	1219	0	20	56	107	10	1	0	ok
3705	2026-08-03 11:00:39.753844+00	0.09	0.5	1906	1245	0	20	56	103	10	1	0	ok
3706	2026-08-03 11:01:39.756909+00	0.03	0	1906	1235	0	20	56	104	10	1	0	ok
3707	2026-08-03 11:02:39.755648+00	0.01	0	1906	1226	0	20	56	105	10	1	0	ok
3708	2026-08-03 11:03:39.754562+00	0	0	1906	1218	0	20	56	107	11	1	0	ok
3709	2026-08-03 11:04:39.757463+00	0.04	0	1906	1220	0	21	56	107	11	1	0	ok
3710	2026-08-03 11:05:39.757194+00	0.01	0	1906	1222	0	21	56	107	11	1	0	ok
3711	2026-08-03 11:06:39.758846+00	0.31	0	1906	1217	0	21	56	107	11	1	0	ok
3712	2026-08-03 11:07:39.756647+00	0.47	0	1906	1221	0	21	56	107	11	1	0	ok
3713	2026-08-03 11:08:39.756973+00	0.17	0	1906	1222	0	21	56	107	11	1	0	ok
3714	2026-08-03 11:09:39.759239+00	0.11	0	1906	1219	0	21	56	108	11	1	0	ok
3715	2026-08-03 11:10:39.757887+00	0.04	0	1906	1219	0	21	56	108	11	1	0	ok
3716	2026-08-03 11:11:39.759257+00	0.24	0	1906	1223	0	21	56	111	12	1	0	ok
3717	2026-08-03 11:12:39.758214+00	0.08	0	1906	1227	0	21	56	109	10	1	0	ok
3718	2026-08-03 11:13:39.75933+00	0.03	0	1906	1232	0	21	56	109	10	1	0	ok
3719	2026-08-03 11:14:39.759518+00	0.01	0	1906	1232	0	21	56	109	10	1	0	ok
3720	2026-08-03 11:15:39.761919+00	0	0.5	1906	1222	0	21	56	110	10	1	0	ok
3721	2026-08-03 11:16:39.761472+00	0.09	0	1906	1225	0	21	56	110	10	1	0	ok
3722	2026-08-03 11:17:39.764226+00	0.03	0	1906	1222	0	21	56	110	10	1	0	ok
3723	2026-08-03 11:18:39.761928+00	0.05	0	1906	1208	0	21	56	110	10	1	0	ok
3724	2026-08-03 11:19:39.763328+00	0.02	0	1906	1238	0	21	56	111	11	1	0	ok
3725	2026-08-03 11:20:39.763532+00	0.31	0	1906	1229	0	21	56	110	10	1	0	ok
3726	2026-08-03 11:21:39.76407+00	0.33	0	1906	1217	0	21	56	111	10	1	0	ok
3727	2026-08-03 11:22:39.765788+00	0.25	0.5	1906	1222	0	21	56	110	11	1	0	ok
3728	2026-08-03 11:23:39.763897+00	0.09	0	1906	1218	0	21	56	110	11	1	0	ok
3729	2026-08-03 11:24:39.766798+00	0.34	0	1906	1215	0	21	56	113	11	1	0	ok
3730	2026-08-03 11:25:39.765934+00	0.48	0	1906	1218	0	21	56	113	11	1	0	ok
3731	2026-08-03 11:26:39.767483+00	0.49	0	1906	1218	0	21	56	114	12	1	0	ok
3732	2026-08-03 11:27:39.767424+00	0.4	0	1906	1226	0	21	56	115	11	1	0	ok
3733	2026-08-03 11:28:39.768529+00	0.15	0	1906	1218	0	21	56	115	11	1	0	ok
3734	2026-08-03 11:29:39.768628+00	0.05	0	1906	1220	0	21	56	114	12	1	0	ok
3735	2026-08-03 11:30:39.768605+00	0.42	0	1906	1218	0	21	56	115	11	1	0	ok
3736	2026-08-03 11:31:39.770371+00	0.42	0	1906	1218	0	21	56	115	12	1	0	ok
3737	2026-08-03 11:32:39.77001+00	0.29	0	1906	1226	0	21	56	115	12	1	0	ok
3738	2026-08-03 11:33:39.769785+00	0.1	0	1906	1210	0	21	56	119	11	1	0	ok
3739	2026-08-03 11:34:39.771075+00	0.31	0	1906	1223	0	21	57	118	12	1	0	ok
3740	2026-08-03 11:35:39.771405+00	0.38	0	1906	1211	0	21	57	119	11	1	0	ok
3741	2026-08-03 11:36:39.77236+00	0.41	0	1906	1223	0	21	57	119	13	1	0	ok
3742	2026-08-03 11:37:39.774985+00	0.46	0	1906	1214	0	21	57	120	12	1	0	ok
3743	2026-08-03 11:38:39.772476+00	0.17	0	1906	1210	0	21	57	119	12	1	0	ok
3744	2026-08-03 11:39:39.773478+00	0.42	0	1906	1211	0	21	57	118	11	1	0	ok
3745	2026-08-03 11:40:39.774684+00	0.42	0	1906	1220	0	21	57	120	13	1	0	ok
3746	2026-08-03 11:41:39.776572+00	0.49	0	1906	1224	0	21	57	120	12	1	0	ok
3747	2026-08-03 11:42:39.775198+00	0.4	0	1906	1222	0	21	57	120	13	1	0	ok
3748	2026-08-03 11:43:39.778004+00	0.15	0	1906	1230	0	21	57	119	14	1	0	ok
3749	2026-08-03 11:44:39.777144+00	0.27	0	1906	1217	0	21	57	120	13	1	0	ok
3750	2026-08-03 11:45:39.778873+00	0.32	0	1906	1226	0	21	57	120	12	1	0	ok
3751	2026-08-03 11:46:39.779312+00	0.34	0.5	1906	1213	0	21	57	120	13	1	0	ok
3752	2026-08-03 11:47:39.787451+00	0.39	0.51	1906	1231	0	21	57	119	11	1	0	ok
3753	2026-08-03 11:48:39.787284+00	0.41	0	1906	1220	0	21	57	119	12	1	0	ok
3754	2026-08-03 11:49:39.790236+00	0.15	0	1906	1231	0	21	57	120	13	1	0	ok
3755	2026-08-03 11:50:39.78756+00	0.05	0	1906	1221	0	21	57	120	11	1	0	ok
3756	2026-08-03 11:51:39.789894+00	0.24	0	1906	1221	0	21	57	120	11	1	0	ok
3757	2026-08-03 11:51:43.199876+00	0.46	0	1906	1272	0	21	57	99	12	1	0	ok
3758	2026-08-03 11:52:43.199359+00	0.29	0	1906	1238	0	21	57	104	11	1	0	ok
3759	2026-08-03 11:53:43.200501+00	0.1	0	1906	1238	0	21	57	108	11	1	0	ok
3760	2026-08-03 11:54:43.202483+00	0.04	0	1906	1223	0	21	57	113	12	1	0	ok
3761	2026-08-03 11:55:43.201154+00	0.01	0	1906	1232	0	21	57	114	11	1	0	ok
3762	2026-08-03 11:56:43.202909+00	0.34	0	1906	1219	0	21	57	116	11	1	0	ok
3763	2026-08-03 11:57:43.203677+00	0.33	0	1906	1217	0	21	57	118	11	1	0	ok
3764	2026-08-03 11:58:43.203527+00	0.41	0	1906	1218	0	21	57	119	12	1	0	ok
3765	2026-08-03 11:59:43.204571+00	0.44	0	1906	1216	0	21	57	119	11	1	0	ok
3766	2026-08-03 12:00:43.202959+00	0.16	0	1906	1223	0	21	57	120	11	1	0	ok
3767	2026-08-03 12:01:43.204524+00	0.36	0	1906	1217	0	21	57	120	12	1	0	ok
3768	2026-08-03 12:02:43.203215+00	0.34	0.5	1906	1215	0	21	57	120	11	1	0	ok
3769	2026-08-03 12:03:43.205031+00	0.2	0	1906	1215	0	21	57	121	11	1	0	ok
3770	2026-08-03 12:04:43.204672+00	0.16	0.5	1906	1232	0	21	57	115	11	1	0	ok
3771	2026-08-03 12:05:43.212042+00	0.3	0	1906	1226	0	21	57	120	10	1	0	ok
3772	2026-08-03 12:06:43.203387+00	0.3	0	1906	1231	0	21	57	120	11	0	0	ok
3773	2026-08-03 12:07:43.204606+00	0.19	0	1906	1216	0	21	57	120	11	0	0	ok
3774	2026-08-03 12:08:43.205109+00	0.07	0	1906	1224	0	21	57	120	11	0	0	ok
3775	2026-08-03 12:09:43.205992+00	0.15	0	1906	1217	0	21	57	119	16	0	0	ok
3776	2026-08-03 12:10:43.205377+00	0.17	0	1906	1207	0	21	57	119	15	0	0	ok
3777	2026-08-03 12:11:43.20595+00	0.24	0	1906	1234	0	21	57	119	11	0	0	ok
3778	2026-08-03 12:12:43.205977+00	0.42	0	1906	1228	0	21	56	119	14	1	0	ok
3779	2026-08-03 12:13:43.204968+00	0.48	0	1906	1231	0	21	56	119	13	1	0	ok
3780	2026-08-03 12:14:43.20513+00	0.42	0	1906	1229	0	21	56	120	12	1	0	ok
3781	2026-08-03 12:15:43.206806+00	0.15	0	1906	1226	0	21	56	119	11	1	0	ok
3782	2026-08-03 12:16:43.205943+00	0.22	0	1906	1216	0	21	56	121	12	1	0	ok
3783	2026-08-03 12:17:43.20649+00	0.12	0	1906	1221	0	21	56	121	14	1	0	ok
3784	2026-08-03 12:18:43.207341+00	0.16	0	1906	1210	0	21	56	120	13	1	0	ok
3785	2026-08-03 12:19:43.205417+00	0.1	0	1906	1221	0	21	56	121	14	1	0	ok
3786	2026-08-03 12:20:43.207505+00	0.16	0	1906	1221	0	21	56	121	14	1	0	ok
3787	2026-08-03 12:21:43.20542+00	0.26	0	1906	1228	0	21	56	121	10	1	0	ok
3788	2026-08-03 12:22:43.205774+00	0.09	0	1906	1226	0	21	57	121	13	1	0	ok
3789	2026-08-03 12:23:43.206555+00	0.19	0	1906	1227	0	21	57	122	12	1	0	ok
3790	2026-08-03 12:24:43.20781+00	0.27	0	1906	1232	0	21	57	121	11	1	0	ok
3791	2026-08-03 12:25:43.209364+00	0.39	0	1906	1227	0	21	57	121	12	1	0	ok
3792	2026-08-03 12:26:43.210454+00	0.43	0	1906	1212	0	21	57	127	12	1	0	ok
3793	2026-08-03 12:27:43.209114+00	0.4	0	1906	1221	0	21	57	128	11	1	0	ok
3794	2026-08-03 12:28:43.208315+00	0.23	0	1906	1209	0	21	57	129	20	1	0	ok
3795	2026-08-03 12:29:43.209486+00	0.12	0	1906	1209	0	21	57	128	12	1	0	ok
3796	2026-08-03 12:30:43.209219+00	0.29	0	1906	1224	0	21	57	128	12	1	0	ok
3797	2026-08-03 12:31:43.21008+00	0.1	0	1906	1218	0	21	57	128	12	1	0	ok
3798	2026-08-03 12:32:43.209105+00	0.04	0	1906	1216	0	21	57	128	10	1	0	ok
3799	2026-08-03 12:33:43.20909+00	0.01	0	1906	1213	0	21	57	129	14	1	0	ok
3800	2026-08-03 12:34:43.209957+00	0	0	1906	1219	0	21	57	128	12	1	0	ok
3801	2026-08-03 12:35:43.212588+00	0	0	1906	1219	0	21	57	128	12	1	0	ok
3802	2026-08-03 12:36:43.212251+00	0	0	1906	1228	0	21	57	128	9	1	0	ok
3803	2026-08-03 12:37:43.210581+00	0	0	1906	1232	0	21	57	128	8	1	0	ok
3804	2026-08-03 12:38:43.210905+00	0.06	0	1906	1224	0	21	57	129	10	1	0	ok
3805	2026-08-03 12:39:43.211033+00	0.06	0	1906	1224	0	21	57	128	10	1	0	ok
3806	2026-08-03 12:40:43.211592+00	0.06	0	1906	1221	0	21	57	128	10	1	0	ok
3807	2026-08-03 12:41:43.212383+00	0.07	0	1906	1230	0	21	57	128	10	1	0	ok
3808	2026-08-03 12:42:43.210192+00	0.02	0	1906	1222	0	21	57	128	10	1	0	ok
3809	2026-08-03 12:43:43.210168+00	0.01	0	1906	1224	0	21	57	129	10	1	0	ok
3810	2026-08-03 12:44:43.211472+00	0	0	1906	1215	0	21	57	128	15	1	0	ok
3811	2026-08-03 12:45:43.222285+00	0	0	1906	1215	0	21	57	131	14	1	0	ok
3812	2026-08-03 12:46:43.208668+00	0	0	1906	1209	0	21	57	129	19	1	0	ok
3813	2026-08-03 12:47:43.211931+00	0	0	1906	1213	0	21	57	129	12	1	0	ok
3814	2026-08-03 12:48:43.210195+00	0	0	1906	1208	0	21	57	129	12	1	0	ok
3815	2026-08-03 12:49:43.211163+00	0	0	1906	1214	0	21	57	129	15	1	0	ok
3816	2026-08-03 12:50:43.211258+00	0.16	0.5	1906	1218	0	21	57	129	9	1	0	ok
3817	2026-08-03 12:51:43.213461+00	0.06	0	1906	1219	0	21	57	130	16	1	0	ok
3818	2026-08-03 12:52:43.212487+00	0.02	0	1906	1215	0	21	57	130	13	1	0	ok
3819	2026-08-03 12:53:43.211238+00	0	0	1906	1221	0	21	57	130	12	1	0	ok
3820	2026-08-03 12:54:43.210636+00	0	0	1906	1216	0	21	57	131	8	1	0	ok
3821	2026-08-03 12:55:43.211045+00	0.04	0	1906	1224	0	21	57	130	11	1	0	ok
3822	2026-08-03 12:56:43.213099+00	0.07	0	1906	1218	0	21	57	132	11	1	0	ok
3823	2026-08-03 12:57:43.214172+00	0.02	0	1906	1226	0	21	57	127	11	1	0	ok
3824	2026-08-03 12:58:43.214239+00	0.05	0	1906	1218	0	21	57	130	10	1	0	ok
3825	2026-08-03 12:59:43.218235+00	0.02	0	1906	1213	0	21	57	130	10	1	0	ok
3826	2026-08-03 13:00:43.219401+00	0.17	0.5	1906	1216	0	21	57	134	10	1	0	ok
3827	2026-08-03 13:01:43.215911+00	0.06	0	1906	1217	0	21	57	131	10	1	0	ok
3828	2026-08-03 13:02:43.215619+00	0.02	0	1906	1221	0	21	57	131	10	1	0	ok
3829	2026-08-03 13:03:43.221259+00	0.01	0	1906	1217	0	21	57	132	10	1	0	ok
3830	2026-08-03 13:04:43.216722+00	0.08	0	1906	1222	0	21	57	132	10	1	0	ok
3831	2026-08-03 13:05:43.217658+00	0.03	0	1906	1213	0	21	57	133	10	1	0	ok
3832	2026-08-03 13:06:43.21806+00	0.17	0	1906	1219	0	21	57	133	10	1	0	ok
3833	2026-08-03 13:07:43.221853+00	0.06	0	1906	1213	0	21	57	133	12	1	0	ok
3834	2026-08-03 13:08:43.222629+00	0.12	0	1906	1218	0	21	57	132	10	1	0	ok
3835	2026-08-03 13:09:43.223904+00	0.04	0	1906	1211	0	21	57	132	10	1	0	ok
3836	2026-08-03 13:10:43.228231+00	0.09	0	1906	1224	0	21	57	133	10	1	0	ok
3837	2026-08-03 13:11:43.226659+00	0.03	0.5	1906	1222	0	21	57	133	11	1	0	ok
3838	2026-08-03 13:12:43.225655+00	0.01	0	1906	1221	0	21	57	133	10	1	0	ok
3839	2026-08-03 13:13:43.22714+00	0	0	1906	1225	0	21	57	134	11	1	0	ok
3840	2026-08-03 13:14:43.228337+00	0	0	1906	1210	0	21	57	133	10	1	0	ok
3841	2026-08-03 13:15:43.225536+00	0	0	1906	1217	0	21	57	133	10	1	0	ok
3842	2026-08-03 13:16:43.228577+00	0	0	1906	1215	0	21	57	133	10	1	0	ok
3843	2026-08-03 13:17:43.226475+00	0.11	0	1906	1222	0	21	57	133	10	1	0	ok
3844	2026-08-03 13:18:43.229357+00	0.18	0	1906	1215	0	21	57	134	10	1	0	ok
3845	2026-08-03 13:19:43.227444+00	0.07	0	1906	1213	0	21	57	133	10	1	0	ok
3846	2026-08-03 13:20:43.245245+00	0.02	0	1906	1225	0	21	57	133	10	1	0	ok
3847	2026-08-03 13:21:43.228291+00	0.01	0	1906	1221	0	21	57	133	10	1	0	ok
3848	2026-08-03 13:22:43.227046+00	0	0	1906	1213	0	21	57	133	10	1	0	ok
3849	2026-08-03 13:23:43.230772+00	0	0	1906	1223	0	21	57	134	10	1	0	ok
3850	2026-08-03 13:24:43.230838+00	0.04	0	1906	1218	0	21	57	133	10	1	0	ok
3851	2026-08-03 13:25:43.231927+00	0.01	0	1906	1219	0	21	57	133	11	1	0	ok
3852	2026-08-03 13:26:43.231483+00	0.07	0	1906	1216	0	21	57	133	12	1	0	ok
3853	2026-08-03 13:27:43.230977+00	0.02	0.5	1906	1206	0	21	57	133	12	1	0	ok
3854	2026-08-03 13:28:43.233813+00	0.01	0	1906	1211	0	21	57	133	10	1	0	ok
3855	2026-08-03 13:29:43.234962+00	0	0	1906	1222	0	21	57	134	10	1	0	ok
3856	2026-08-03 13:30:43.234258+00	0.29	0	1906	1221	0	21	57	133	10	1	0	ok
3857	2026-08-03 13:31:43.236587+00	0.1	0	1906	1228	0	21	57	134	11	1	0	ok
3858	2026-08-03 13:32:43.236259+00	0.04	0	1906	1218	0	21	57	134	10	1	0	ok
3859	2026-08-03 13:33:33.261897+00	0.01	0	1906	1283	0	21	57	99	12	1	0	ok
3860	2026-08-03 13:34:33.261441+00	0	0	1906	1248	0	21	57	94	10	1	0	ok
3861	2026-08-03 13:35:33.263735+00	0	0	1906	1240	0	21	57	97	10	1	0	ok
3862	2026-08-03 13:36:33.262903+00	0	0	1906	1241	0	21	57	105	10	1	0	ok
3863	2026-08-03 13:37:33.261+00	0.03	0	1906	1241	0	21	57	106	10	1	0	ok
3864	2026-08-03 13:38:33.262256+00	0.04	0	1906	1234	0	21	57	109	10	1	0	ok
3865	2026-08-03 13:39:33.266295+00	0.05	0	1906	1232	0	21	57	109	11	1	0	ok
3866	2026-08-03 13:40:33.266361+00	0.05	0	1906	1236	0	21	57	108	10	1	0	ok
3867	2026-08-03 13:41:33.267303+00	0.02	0	1906	1235	0	21	57	109	12	1	0	ok
3868	2026-08-03 13:42:33.265524+00	0	0	1906	1236	0	21	57	110	10	1	0	ok
3869	2026-08-03 13:43:33.265885+00	0	0	1906	1227	0	21	57	109	11	1	0	ok
3870	2026-08-03 13:44:33.275326+00	0.05	0	1906	1225	0	21	57	109	12	1	0	ok
3871	2026-08-03 13:45:33.275382+00	0.02	0	1906	1225	0	21	57	109	11	1	0	ok
3872	2026-08-03 13:46:33.275619+00	0	0	1906	1240	0	21	57	110	10	1	0	ok
3873	2026-08-03 13:47:33.276822+00	0	0	1906	1228	0	21	57	110	10	1	0	ok
3874	2026-08-03 13:48:33.277059+00	0	0	1906	1233	0	21	57	109	10	1	0	ok
3875	2026-08-03 13:49:22.046448+00	0	0	1906	1271	0	21	57	99	12	1	0	ok
3876	2026-08-03 13:50:22.048843+00	0	0	1906	1251	0	21	57	91	16	1	0	ok
3877	2026-08-03 13:51:22.049736+00	0	0	1906	1236	0	21	57	108	16	1	0	ok
3878	2026-08-03 13:52:22.047266+00	0	0	1906	1236	0	21	57	111	10	1	0	ok
3879	2026-08-03 13:53:22.053925+00	0	0	1906	1236	0	21	57	106	13	1	0	ok
3880	2026-08-03 13:54:22.050648+00	0	0	1906	1233	0	21	57	109	12	1	0	ok
3881	2026-08-03 13:54:53.879514+00	0	0	1906	1271	0	21	57	99	12	1	0	ok
3882	2026-08-03 13:55:53.881061+00	0.04	0	1906	1251	0	21	57	96	11	1	0	ok
3883	2026-08-03 13:56:53.881689+00	0.05	0	1906	1247	0	21	57	101	13	1	0	ok
3884	2026-08-03 13:57:53.883225+00	0.09	0	1906	1234	0	21	57	112	12	1	0	ok
3885	2026-08-03 13:58:53.882122+00	0.03	0.5	1906	1245	0	21	57	111	13	1	0	ok
3886	2026-08-03 13:59:53.88212+00	0.01	0	1906	1240	0	21	57	114	9	1	0	ok
3887	2026-08-03 14:00:53.882126+00	0.04	0	1906	1242	0	21	57	114	9	1	0	ok
3888	2026-08-03 14:01:53.88185+00	0.01	0	1906	1233	0	21	57	114	10	1	0	ok
3889	2026-08-03 14:02:53.881402+00	0	0	1906	1234	0	21	57	115	11	1	0	ok
3890	2026-08-03 14:03:53.883038+00	0	0	1906	1240	0	21	57	115	10	1	0	ok
3891	2026-08-03 14:04:53.882089+00	0	0	1906	1237	0	21	57	115	12	1	0	ok
3892	2026-08-03 14:05:53.885315+00	0	0	1906	1236	0	21	57	115	12	1	0	ok
3893	2026-08-03 14:06:53.8859+00	0	0	1906	1231	0	21	57	116	13	1	0	ok
3894	2026-08-03 14:07:53.884448+00	0	0	1906	1233	0	21	57	117	10	1	0	ok
3895	2026-08-03 14:08:53.885835+00	0	0.5	1906	1244	0	21	57	117	12	1	0	ok
3896	2026-08-03 14:09:53.886676+00	0.03	0	1906	1242	0	21	57	117	11	1	0	ok
3897	2026-08-03 14:10:53.889245+00	0.06	0	1906	1230	0	21	57	117	13	1	0	ok
3898	2026-08-03 14:11:53.88767+00	0.1	0	1906	1238	0	21	57	118	11	1	0	ok
3899	2026-08-03 14:12:53.886307+00	0.04	0	1906	1236	0	21	57	118	13	1	0	ok
3900	2026-08-03 14:13:53.888186+00	0.01	0.5	1906	1234	0	21	57	118	10	1	0	ok
3901	2026-08-03 14:14:53.887602+00	0	0.5	1906	1236	0	21	57	118	11	1	0	ok
3902	2026-08-03 14:15:53.889721+00	0	0	1906	1225	0	21	57	119	12	1	0	ok
3903	2026-08-03 14:16:53.889305+00	0	0	1906	1235	0	21	57	118	12	1	0	ok
3904	2026-08-03 14:17:53.889539+00	0	0	1906	1228	0	21	57	118	12	1	0	ok
3905	2026-08-03 14:18:53.889383+00	0	0	1906	1227	0	21	57	118	12	1	0	ok
3906	2026-08-03 14:19:11.850084+00	0	0	1906	1269	0	21	57	98	14	1	0	ok
3907	2026-08-03 14:20:11.851741+00	0	0	1906	1226	0	21	57	102	18	1	0	ok
3908	2026-08-03 14:21:11.857029+00	0.16	0	1906	1225	0	21	57	105	18	1	0	ok
3909	2026-08-03 14:22:11.856337+00	0.06	0	1906	1218	0	21	57	109	18	1	0	ok
3910	2026-08-03 14:23:11.858563+00	0.02	0.5	1906	1238	0	21	57	110	17	1	0	ok
3911	2026-08-03 14:24:11.859481+00	0	0	1906	1222	0	21	57	114	19	1	0	ok
3912	2026-08-03 14:25:11.860671+00	0	0	1906	1218	0	21	57	117	17	1	0	ok
3913	2026-08-03 14:26:11.859641+00	0	0	1906	1226	0	21	57	119	16	1	0	ok
3914	2026-08-03 14:27:11.860346+00	0	0	1906	1224	0	21	57	120	15	1	0	ok
3915	2026-08-03 14:28:11.860112+00	0	0	1906	1223	0	21	57	120	17	1	0	ok
3916	2026-08-03 14:28:39.26452+00	0	0	1906	1268	0	21	57	98	14	1	0	ok
3917	2026-08-03 14:29:39.263857+00	0.16	0.5	1906	1247	0	21	57	98	17	1	0	ok
3918	2026-08-03 14:30:39.267828+00	0.1	0	1906	1239	0	21	57	103	14	1	0	ok
3919	2026-08-03 14:31:39.265009+00	0.04	0	1906	1233	0	21	57	101	13	1	0	ok
3920	2026-08-03 14:32:39.26511+00	0.01	0	1906	1243	0	21	57	102	14	1	0	ok
3921	2026-08-03 14:33:39.265364+00	0.09	0	1906	1236	0	21	57	105	12	1	0	ok
3922	2026-08-03 14:34:39.269302+00	0.08	0.5	1906	1238	0	21	57	107	15	1	0	ok
3923	2026-08-03 14:35:39.26548+00	0.07	0	1906	1233	0	21	57	107	9	1	0	ok
3924	2026-08-03 14:36:39.266575+00	0.02	0	1906	1239	0	21	57	108	9	1	0	ok
3925	2026-08-03 14:37:39.270011+00	0.05	0	1906	1243	0	21	57	108	9	1	0	ok
3926	2026-08-03 14:38:39.267658+00	0.02	0	1906	1242	0	21	57	108	9	1	0	ok
3927	2026-08-03 14:39:39.266532+00	0.05	0	1906	1229	0	21	57	108	10	1	0	ok
3928	2026-08-03 14:40:39.266949+00	0.06	0	1906	1234	0	21	57	109	11	1	0	ok
3929	2026-08-03 14:41:39.270455+00	0.02	0	1906	1230	0	21	57	108	10	1	0	ok
3930	2026-08-03 14:42:39.270105+00	0.05	0	1906	1236	0	21	57	109	11	1	0	ok
3931	2026-08-03 14:43:39.270441+00	0.07	0	1906	1227	0	21	57	111	10	1	0	ok
3932	2026-08-03 14:44:39.271276+00	0.03	0	1906	1243	0	21	57	107	10	1	0	ok
3933	2026-08-03 14:45:39.27992+00	0.05	0	1906	1233	0	21	57	111	11	1	0	ok
3934	2026-08-03 14:46:39.287446+00	0.02	0	1906	1232	0	21	57	111	10	1	0	ok
3935	2026-08-03 14:47:39.279924+00	0.05	0	1906	1238	0	21	57	114	10	1	0	ok
3936	2026-08-03 14:48:39.294657+00	0.22	0.5	1906	1234	0	21	57	109	11	1	0	ok
3937	2026-08-03 14:49:39.280105+00	0.08	0	1906	1219	0	21	57	110	11	1	0	ok
3938	2026-08-03 14:50:39.279744+00	0.03	0	1906	1232	0	21	57	107	11	1	0	ok
3939	2026-08-03 14:51:39.278864+00	0.16	0	1906	1230	0	21	57	108	11	1	0	ok
3940	2026-08-03 14:52:39.280305+00	0.06	0	1906	1236	0	21	57	112	10	1	0	ok
\.


--
-- Data for Name: system_health_alerts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_health_alerts (id, metric, severity, value, threshold, message, opened_at, closed_at) FROM stdin;
1	routers_down	warning	1	0	Router(s) unreachable: 1 (threshold > 0). Affected ISPs cannot authenticate customers.	2026-07-31 09:51:37.839908+00	2026-07-31 09:59:37.841971+00
2	cpu_steal	critical	8.96	5	CPU throttled by AWS: 8.96 % (threshold > 5). Burst credits are exhausted. Only a plan with more vCPUs resolves this.	2026-08-01 15:21:02.83619+00	2026-08-01 15:34:39.286647+00
3	cpu_steal	critical	16.42	5	CPU throttled by AWS: 16.42 % (threshold > 5). Burst credits are exhausted. Only a plan with more vCPUs resolves this.	2026-08-03 10:11:03.766885+00	2026-08-03 10:12:03.787295+00
\.


--
-- Data for Name: usage_daily; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily (isp_id, device_id, username, usage_day, bytes_in, bytes_out, updated_at) FROM stdin;
cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	benard	2026-08-03	37600254	43744526	2026-08-03 14:49:02.34182+00
cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	AE:C1:5C:88:4A:7F	2026-08-03	61100	124029	2026-08-03 13:28:01.775641+00
cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	Q1@cc49de72	2026-08-03	717553	3560035	2026-08-03 13:56:02.342828+00
cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	Q2@cc49de72	2026-08-03	57374968	313019596	2026-08-03 14:14:02.050239+00
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
37aa197b1a997e8e04e61f0ddd6d4acc	81000000	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	0	0	2026-08-03 12:16:02.181252+00
abb5d0b5b65979f824ff31c9194805ca	81000002	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	0	0	2026-08-03 12:17:01.955263+00
bf9a84a8808e84c2cef64d09e24f8852	8100000a	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	165330	183353	2026-08-03 14:53:01.358253+00
d17671633933e8d04e7d3325328f730f	81000003	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	17563037	29045567	2026-08-03 12:23:01.454277+00
c648c0c3e574d21ea6994551b57aea1b	80000009	Q2@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	724157	5731474	2026-08-03 12:36:01.288391+00
6851ab95d61c187b52edb474d13e3b46	80000012	Q2@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	38833620	189847874	2026-08-03 13:26:02.116387+00
3aae456f62c59d80cc9807ef8baca7a8	81000004	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	1638	1880	2026-08-03 14:17:02.100253+00
ef5db2d4d5fdeac6936c26a0a6d6c535	80000015	AE:C1:5C:88:4A:7F	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	61100	124029	2026-08-03 13:31:02.091086+00
566017933ffdaae8c3ca82e09fcb4315	8000001d	Q2@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	8203655	34763720	2026-08-03 14:18:01.878689+00
5220f1c8cb01da84d8522bf9ffa122c7	8000000b	Q2@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	580460	1523436	2026-08-03 12:49:01.250702+00
367b1f311c0a130bfc73583159323c64	81000005	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	18678	21160	2026-08-03 14:22:01.897738+00
683a8107f9e6e3d4075942e6ee1dc14f	81000006	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	152190	144798	2026-08-03 14:25:01.887257+00
b99baf2db25d1565bfa31fb2111e1a91	8000000f	Q1@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	487757	3307251	2026-08-03 12:55:02.051019+00
fdce9be7459cc6ba22f31a147550e6a9	80000010	Q1@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	38015	64092	2026-08-03 12:56:02.240909+00
8e6b6f95b0e247a3a753f2b51ddfe00b	81000007	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	19701019	14349648	2026-08-03 14:31:01.53039+00
5911c62ef61e0aa61cb3f1ef1de15734	80000016	Q2@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	9033076	81153092	2026-08-03 13:55:02.46224+00
5ad5a36dc6b6b3413fe18f3ce903428d	81000008	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	2230	2624	2026-08-03 14:31:01.53039+00
77691a82ec8cd3e27f737c82de0e1f6f	81000009	benard	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	222	296	2026-08-03 14:31:01.53039+00
4f745c955f875d4e5e9d065de89f348a	80000019	Q1@cc49de72	cc49de72-5ea8-402b-865a-c2fa66698151	dc313eb1-020f-465f-8dd5-a2d0e0f4f7d7	191781	188692	2026-08-03 13:58:01.881732+00
\.


--
-- Data for Name: verification_codes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_codes (id, isp_id, channel, target, code_hash, expires_at, attempts, consumed_at, ip, created_at, selector) FROM stdin;
1	cc49de72-5ea8-402b-865a-c2fa66698151	email	rumalinkenterprise@gmail.com	2de153b66260bc4f.132a7e2448462fd3d305d5d0e8a7639120902546c6b34e1921fa7bc5281a7206	2026-08-04 12:07:39.902638+00	0	2026-08-03 12:08:18.378951+00	102.205.237.69	2026-08-03 12:07:39.902638+00	55858e8c0f4d
2	cc49de72-5ea8-402b-865a-c2fa66698151	phone	254704994652	e38ae137ab950af8.b814bd4088e91e084856ae97e4ca3a474d9c53ccf49cf8e06d02e520af40b099	2026-08-03 12:18:25.518455+00	0	2026-08-03 12:09:26.599306+00	102.205.237.69	2026-08-03 12:08:25.518455+00	\N
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

SELECT pg_catalog.setval('public.nas_id_seq', 1, true);


--
-- Name: radacct_radacctid_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radacct_radacctid_seq', 20, true);


--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.radcheck_delete_audit_id_seq', 391, true);


--
-- Name: radcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radcheck_id_seq', 105, true);


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

SELECT pg_catalog.setval('public.radpostauth_id_seq', 43, true);


--
-- Name: radreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radreply_id_seq', 1239, true);


--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_alerts_id_seq', 3, true);


--
-- Name: system_health_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_id_seq', 3940, true);


--
-- Name: verification_codes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_codes_id_seq', 2, true);


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
-- Name: system_health_alerts system_health_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health_alerts
    ADD CONSTRAINT system_health_alerts_pkey PRIMARY KEY (id);


--
-- Name: system_health system_health_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health
    ADD CONSTRAINT system_health_pkey PRIMARY KEY (id);


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
-- Name: idx_sys_alerts_open; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sys_alerts_open ON public.system_health_alerts USING btree (closed_at) WHERE (closed_at IS NULL);


--
-- Name: idx_sys_health_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sys_health_time ON public.system_health USING btree (sampled_at DESC);


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
-- Name: idx_vouchers_purchased_mac; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_purchased_mac ON public.hotspot_vouchers USING btree (isp_id, upper((purchased_by_mac)::text));


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
-- Name: TABLE system_health; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.system_health TO rumalink_user;


--
-- Name: TABLE system_health_alerts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.system_health_alerts TO rumalink_user;


--
-- Name: SEQUENCE system_health_alerts_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.system_health_alerts_id_seq TO rumalink_user;


--
-- Name: SEQUENCE system_health_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.system_health_id_seq TO rumalink_user;


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

\unrestrict iZsv1gZWdjjSdhjHGz1p1VxsjWb1CWUVWbtZAdZuyGiZfM5R3YJnmThj7IE4HXt

