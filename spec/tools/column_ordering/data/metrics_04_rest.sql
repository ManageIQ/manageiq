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

