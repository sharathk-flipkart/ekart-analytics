INSERT OVERWRITE TABLE tracking_shipment_l0_hive_fact
SELECT
a.consignment_id,
a.consignment_connection_id,
a.consignment_type,
a.consignment_mode,
a.connection_type,
a.connection_transit_type,
a.connection_code,
a.connection_frequency_type,
a.consignment_status,
a.consignment_co_loader,
a.consignment_breach_flag,
a.consignment_movement_flag,
a.consignment_source_hub_type,
a.consignment_destination_hub_type,
lookupkey('facility_id',a.consignment_source_hub_id) AS consignment_source_hub_id_key,
lookupkey('facility_id',a.consignment_destination_hub_id) AS consignment_destination_hub_id_key,
lookup_date(a.connection_cut_off_datetime) AS connection_cut_off_date_key,
lookup_time(a.connection_cut_off_datetime) AS connection_cut_off_time_key,
lookup_date(a.consignment_create_datetime) AS consignment_create_date_key,
lookup_time(a.consignment_create_datetime) AS consignment_create_time_key,
lookup_date(a.consignment_status_date_time) AS consignment_status_date_key,
lookup_time(a.consignment_status_date_time) AS consignment_status_time_key,
lookup_date(a.consignment_eta_datetime) AS consignment_eta_date_key,
lookup_time(a.consignment_eta_datetime) AS consignment_eta_time_key,
lookup_date(a.consignment_received_datetime) AS consignment_received_date_key,
lookup_time(a.consignment_received_datetime) AS consignment_received_time_key,
a.bag_id as bag_id,
g.bag_tracking_id as bag_tracking_id,
g.bag_seal_id as bag_seal_id,
lookupkey('facility_id',g.bag_source_hub_id) as bag_source_hub_id_key,
lookupkey('facility_id',g.bag_assigned_hub_id) as bag_assigned_hub_id_key,
lookup_date(cast(d.bag_inscan as TIMESTAMP)) as bag_inscan_date_key,
lookup_time(cast(d.bag_inscan as TIMESTAMP)) as bag_inscan_time_key,
a.vendor_tracking_id as vendor_tracking_id,
lookup_date(cast(e.shipment_inscan as TIMESTAMP)) as shipment_inscan_date_key,
lookup_time(cast(e.shipment_inscan as TIMESTAMP)) as shipment_inscan_time_key,
a.consignment_create_datetime as consignment_create_datetime,
a.consignment_received_datetime as consignment_received_datetime,
a.consignment_status_date_time as consignment_status_datetime,
a.connection_cut_off_datetime as connection_cut_off_datetime,
cast(d.bag_inscan as TIMESTAMP) as bag_inscan_datetime,
cast(e.shipment_inscan as TIMESTAMP) as shipment_inscan_datetime,
If(a.consignment_co_loader in ('CSDTransport','TH_ABBAS_TRANSPORT','Super_India_Logistics','Harsha Transport','Truck_Fast','SVC Roadlines','Rishabh Cargo','Dhir Roadways','SajalMajumder','Trans_Cargo_India','Mahi Transport','STCS_Logistics','Ghosh_Enterpirses','CENTURY_CARGO_CARRIER','Kailash'),1,0) as ftl_flag
from 
(select x.consignment_id as consignment_id,
b.bag_id as bag_id,
c.shipment_id as vendor_tracking_id,
x.consignment_connection_id,
x.consignment_type,
x.consignment_mode,
x.connection_type,
x.connection_transit_type,
x.connection_code,
x.connection_frequency_type,
x.consignment_status,
x.consignment_co_loader,
x.consignment_breach_flag,
x.consignment_movement_flag,
x.consignment_source_hub_type,
x.consignment_destination_hub_type,
x.consignment_source_hub_id as consignment_source_hub_id,
x.consignment_destination_hub_id as consignment_destination_hub_id,
lookupkey('facility_id',x.consignment_source_hub_id) AS consignment_source_hub_id_key,
lookupkey('facility_id',x.consignment_destination_hub_id) AS consignment_destination_hub_id_key,
x.connection_cut_off_datetime AS connection_cut_off_datetime,
x.consignment_create_datetime AS consignment_create_datetime,
x.consignment_status_date_time AS consignment_status_date_time,
x.consignment_eta_datetime AS consignment_eta_datetime,
x.consignment_received_datetime AS consignment_received_datetime
from bigfoot_external_neo.scp_ekl__consignment_l1_90_fact x
left join bigfoot_external_neo.scp_ekl__bag_consignment_map_90_fact b on b.consignment_id = x.consignment_id
left join bigfoot_external_neo.scp_ekl__shipment_closedbag_map_l1_90_fact c on CAST(SPLIT(c.bag, "-")[1] AS INT)  = b.bag_id
where x.consignment_type = 'BAG'
union all
select i.consignment_id,
null as bag_id, 
h.shipment_id as vendor_tracking_id,
i.consignment_connection_id,
i.consignment_type,
i.consignment_mode,
i.connection_type,
i.connection_transit_type,
i.connection_code,
i.connection_frequency_type,
i.consignment_status,
i.consignment_co_loader,
i.consignment_breach_flag,
i.consignment_movement_flag,
i.consignment_source_hub_type,
i.consignment_destination_hub_type,
i.consignment_source_hub_id as consignment_source_hub_id,
i.consignment_destination_hub_id as consignment_destination_hub_id,
lookupkey('facility_id',i.consignment_source_hub_id) AS consignment_source_hub_id_key,
lookupkey('facility_id',i.consignment_destination_hub_id) AS consignment_destination_hub_id_key,
i.connection_cut_off_datetime AS connection_cut_off_datetime,
i.consignment_create_datetime AS consignment_create_datetime,
i.consignment_status_date_time AS consignment_status_date_time,
i.consignment_eta_datetime AS consignment_eta_datetime,
i.consignment_received_datetime AS consignment_received_datetime
from bigfoot_external_neo.scp_ekl__consignment_l1_90_fact i
left join bigfoot_external_neo.scp_ekl__shipment_consignment_map_l1_90_fact h on i.consignment_id = CAST(SPLIT(h.consignment_id, "-")[1] AS INT)
where i.consignment_type = 'SHIPMENT') a
left join (select entityid as bag_id, `data`.current_location.id as current_location,min(updatedat) as bag_inscan from bigfoot_journal.dart_wsr_scp_ekl_shipmentgroup_3 where day  > date_format(date_sub(current_date,90),'yyyyMMdd') and  `data`.status in ('REACHED','CLOSED') and `data`.type = 'bag' group by entityid,`data`.current_location.id) d on CAST(SPLIT(d.bag_id, "-")[1] AS INT)  = a.bag_id and a.consignment_destination_hub_id = d.current_location 
left join (select `data`.vendor_tracking_id as vendor_tracking_id,`data`.current_address.id as current_address, min(updatedat) as shipment_inscan from bigfoot_journal.dart_wsr_scp_ekl_shipment_4 where day  > date_format(date_sub(current_date,90),'yyyyMMdd') and `data`.status = 'Received'group by `data`.vendor_tracking_id,`data`.current_address.id) e on e.vendor_tracking_id = a.vendor_tracking_id and a.consignment_destination_hub_id = e.current_address
left join bigfoot_external_neo.scp_ekl__bag_l1_90_fact g on g.bag_id = a.bag_id;