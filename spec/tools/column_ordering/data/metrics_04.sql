--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: metrics_04; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE metrics_04 (
    id bigint,
    "timestamp" timestamp without time zone,
    capture_interval integer,
    resource_id bigint,
    resource_type character varying(255),
    cpu_usage_rate_average double precision,
    cpu_usagemhz_rate_average double precision,
    mem_usage_absolute_average double precision,
    disk_usage_rate_average double precision,
    net_usage_rate_average double precision,
    sys_uptime_absolute_latest double precision,
    created_on timestamp without time zone,
    derived_cpu_available double precision,
    derived_memory_available double precision,
    derived_memory_used double precision,
    derived_cpu_reserved double precision,
    derived_memory_reserved double precision,
    derived_vm_count_on integer,
    derived_host_count_on integer,
    derived_vm_count_off integer,
    derived_host_count_off integer,
    derived_storage_total double precision,
    derived_storage_free double precision,
    capture_interval_name character varying(255),
    assoc_ids text,
    cpu_ready_delta_summation double precision,
    cpu_system_delta_summation double precision,
    cpu_wait_delta_summation double precision,
    resource_name character varying(255),
    cpu_used_delta_summation double precision,
    tag_names text,
    parent_host_id bigint,
    parent_ems_cluster_id bigint,
    parent_storage_id bigint,
    parent_ems_id bigint,
    derived_storage_vm_count_registered double precision,
    derived_storage_vm_count_unregistered double precision,
    derived_storage_vm_count_unmanaged double precision,
    derived_storage_used_registered double precision,
    derived_storage_used_unregistered double precision,
    derived_storage_used_unmanaged double precision,
    derived_storage_snapshot_registered double precision,
    derived_storage_snapshot_unregistered double precision,
    derived_storage_snapshot_unmanaged double precision,
    derived_storage_mem_registered double precision,
    derived_storage_mem_unregistered double precision,
    derived_storage_mem_unmanaged double precision,
    derived_storage_disk_registered double precision,
    derived_storage_disk_unregistered double precision,
    derived_storage_disk_unmanaged double precision,
    derived_storage_vm_count_managed double precision,
    derived_storage_used_managed double precision,
    derived_storage_snapshot_managed double precision,
    derived_storage_mem_managed double precision,
    derived_storage_disk_managed double precision,
    min_max text,
    intervals_in_rollup integer,
    mem_vmmemctl_absolute_average double precision,
    mem_vmmemctltarget_absolute_average double precision,
    mem_swapin_absolute_average double precision,
    mem_swapout_absolute_average double precision,
    mem_swapped_absolute_average double precision,
    mem_swaptarget_absolute_average double precision,
    derived_vm_used_disk_storage double precision,
    derived_vm_allocated_disk_storage double precision,
    derived_vm_numvcpus double precision,
    disk_devicelatency_absolute_average double precision,
    disk_kernellatency_absolute_average double precision,
    disk_queuelatency_absolute_average double precision,
    time_profile_id bigint,
    CONSTRAINT metrics_04_inheritance_check CHECK ((((capture_interval_name)::text = 'realtime'::text) AND (date_part('hour'::text, "timestamp") = (4)::double precision)))
)
INHERITS (metrics);


ALTER TABLE metrics_04 OWNER TO root;

--
-- Name: metrics_04_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE metrics_04_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE metrics_04_id_seq OWNER TO root;

--
-- Name: metrics_04_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE metrics_04_id_seq OWNED BY metrics_04.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE ONLY metrics_04 ALTER COLUMN id SET DEFAULT nextval('metrics_04_id_seq'::regclass);


--
-- Name: metrics_04_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY metrics_04
    ADD CONSTRAINT metrics_04_pkey PRIMARY KEY (id);


--
-- Name: index_metrics_04_on_resource_and_ts; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX index_metrics_04_on_resource_and_ts ON metrics_04 USING btree (resource_id, resource_type, capture_interval_name, "timestamp");


--
-- Name: index_metrics_04_on_ts_and_capture_interval_name; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX index_metrics_04_on_ts_and_capture_interval_name ON metrics_04 USING btree ("timestamp", capture_interval_name, resource_id, resource_type);


--
-- PostgreSQL database dump complete
--

