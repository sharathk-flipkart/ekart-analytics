INSERT OVERWRITE INSERT OVERWRITE TABLE bag_l1_90_fact
SELECT
CAST( SPLIT(a.entityid, "-")[1] AS INT) AS bag_id,
b.`data`.vendor_tracking_id AS bag_tracking_id,
b.`data`.seal_id AS bag_seal_id,
b.`data`.status AS bag_current_status,
concat_ws('-', b.`data`.attributes) AS bag_category,
size(b.`data`.shipments) AS bag_no_of_shipments,
a.bag_number_of_offloads AS bag_number_of_offloads,
a.bag_number_of_hops AS bag_number_of_hops,
c.status AS bag_first_offload_reason,
If(size(b.`data`.notes) = 0, NULL, If(b.`data`.notes[0].type = 'EtaUpdate Notes',b.`data`.notes[0].flag,NULL)) as bag_eta_update_reason,
b.`data`.system_weight.physical AS bag_system_weight,
b.`data`.sender_weight.physical AS bag_sender_weight,
b.`data`.sender_weight.volumetric AS bag_sender_volumetric_weight,
IF(b.`data`.system_weight.physical > b.`data`.system_weight.volumetric, b.`data`.system_weight.physical, b.`data`.system_weight.volumetric ) AS bag_chargeable_weight,
b.`data`.receiver_weight.physical AS bag_receiver_weight,
b.`data`.transportation_cost.total_charge.value AS bag_transport_cost,
b.`data`.source_location.id AS bag_source_hub_id,
b.`data`.current_location.id AS bag_current_hub_id,
b.`data`.source_location.type as bag_created_hub_type,
b.`data`.current_location.type as bag_current_hub_type,
b.`data`.destination_location.type as bag_destination_hub_type,
b.`data`.destination_location.id AS bag_assigned_hub_id,
b.`data`.created_at as bag_created_at_datetime,
CAST(a.first_close_time AS TIMESTAMP) as bag_first_closed_datetime,
CAST(a.bag_first_connected_time AS TIMESTAMP) as bag_first_connected_datetime,
CAST(a.bag_last_connected_time AS TIMESTAMP) as bag_last_connected_datetime,
CAST(a.last_intermediate_hub_inscan_time AS TIMESTAMP) as bag_last_intermediate_hub_inscan_datetime,
CAST(a.bag_destination_hub_inscan_time AS TIMESTAMP) as bag_destination_hub_inscan_datetime,
CAST(a.bag_receive_time AS TIMESTAMP) AS bag_receive_datetime,
CAST(b.updatedat AS TIMESTAMP) AS bag_last_update_datetime,
CAST(a.bag_first_offload_time AS TIMESTAMP) AS bag_first_offload_datetime,
x.hub_id as source_hub_id,x.scanned_date_time,x.bag_weight,x.machine_id,x.hub_type,x.machine_status,x.weight_entry_type,
y.hub_id as first_hop_id,
y.scanned_date_time as first_inscan,
y.bag_weight as first_hop_weight,
y.machine_id as first_hop_machine_id,
y.hub_type as first_hop_type,
y.machine_status as first_hop_machine_status,
y.weight_entry_type as first_hop_weight_entry_type,
z.hub_id as second_hop_id,
z.scanned_date_time as second_inscan,
z.bag_weight as second_hop_weight,
z.machine_id as second_hop_machine_id,
z.hub_type as second_hop_type,
z.machine_status as second_hop_machine_status,
z.weight_entry_type as second_hop_weight_entry_type,
d.hub_id as third_hop_id,
d.scanned_date_time as third_inscan,
d.bag_weight as third_hop_weight,
d.machine_id as third_hop_machine_id,
d.hub_type as third_hop_type,
d.machine_status as third_hop_machine_status,
d.weight_entry_type as third_hop_weight_entry_type,
y.is_within_tolerance as first_is_within_tolerance,
z.is_within_tolerance as second_is_within_tolerance,
d.is_within_tolerance as third_is_within_tolerance,
dest.machine_id as last_hub_machine_id, 
dest.bag_weight as last_hub_weight,
dest.is_within_tolerance as last_hub_is_within_tolerance,
dest.hub_id as last_hop_id,
dest.scanned_date_time as last_inscan,
dest.hub_type as last_hub_type,
bs.no_of_shipments_inscanned,
b.data.eta as eta_datetime
FROM
(SELECT entityid,
       MIN(updatedat) AS first_time,
       MIN(IF(`data`.status='CLOSED', updatedat, NULL)) AS first_close_time,
       MAX(IF(`data`.status='CLOSED' AND `data`.source_location.id <> `data`.current_location.id, updatedat, NULL)) AS last_intermediate_hub_inscan_time,
       MIN(IF(`data`.status='INTRANSIT', updatedat, NULL)) AS bag_first_connected_time,
       MIN(IF(`data`.status='INTRANSIT', updatedat, NULL)) AS bag_last_connected_time,
       MIN(IF(`data`.status='REACHED', updatedat, NULL)) AS bag_destination_hub_inscan_time,
       MIN(IF(`data`.status='RECEIVED', updatedat, NULL)) AS bag_receive_time,
       SUM(IF(`data`.status LIKE '%Offloaded%', 1, 0)) AS bag_number_of_offloads,
       SUM(IF(`data`.status='CLOSED', 1, 0)) AS bag_number_of_hops,
       MIN(IF(`data`.status LIKE '%Offloaded%', updatedat, NULL)) AS bag_first_offload_time
FROM bigfoot_journal.dart_wsr_scp_ekl_shipmentgroup_3
WHERE lower(`data`.type) = 'bag' and   day > date_format(date_sub(current_date,100),'yyyyMMdd')
GROUP BY entityid) a
LEFT OUTER JOIN 
( select entityid,`data`.status as status,updatedat from bigfoot_journal.dart_wsr_scp_ekl_shipmentgroup_3 where day > date_format(date_sub(current_date,100),'yyyyMMdd'))  c
ON (c.entityid = a.entityid AND c.status LIKE '%Offloaded%' AND c.updatedat = a.bag_first_offload_time)
INNER JOIN bigfoot_snapshot.dart_wsr_scp_ekl_shipmentgroup_3_view b ON (b.entityid = a.entityid)
LEFT JOIN
(
select hub_id,tracking_id,scanned_date_time,bag_weight,rank ,
machine_id,
hub_type,
machine_status,
weight_entry_type,
is_within_tolerance
from
(select data.hub_id,
data.tracking_id,
data.scanned_date_time,
data.bag_weight,
data.machine_id,
data.hub_type,
data.machine_status,
data.weight_entry_type,
data.is_within_tolerance,
ROW_NUMBER() OVER (PARTITION BY data.tracking_id ORDER BY data.scanned_date_time ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)  as rank
from bigfoot_journal.dart_wsr_scp_ekl_weighthistory_1  ) as a1 where a1.rank=1) as x

ON (x.tracking_id=b.data.vendor_tracking_id)
LEFT JOIN
(
select hub_id,tracking_id,scanned_date_time,bag_weight,rank,
machine_id,
hub_type,
machine_status,
weight_entry_type,
is_within_tolerance
from
(select data.hub_id,
data.tracking_id,
data.scanned_date_time,
data.bag_weight,
data.machine_id,
data.hub_type,
data.machine_status,
data.weight_entry_type,
data.is_within_tolerance,
ROW_NUMBER() OVER (PARTITION BY data.tracking_id ORDER BY data.scanned_date_time ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)  as rank
from bigfoot_journal.dart_wsr_scp_ekl_weighthistory_1 ) as b1 where b1.rank=2) as y
on (y.tracking_id=x.tracking_id )
LEFT JOIN
(
select hub_id,tracking_id,scanned_date_time,bag_weight,rank, 
machine_id,
hub_type,
machine_status,
weight_entry_type,
is_within_tolerance
from
(select data.hub_id,
data.tracking_id,
data.scanned_date_time,
data.bag_weight,
data.machine_id,
data.hub_type,
data.machine_status,
data.weight_entry_type,
data.is_within_tolerance,
ROW_NUMBER() OVER (PARTITION BY data.tracking_id ORDER BY data.scanned_date_time ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)  as rank
from bigfoot_journal.dart_wsr_scp_ekl_weighthistory_1  ) as c1 where c1.rank=3) as z
ON (z.tracking_id=x.tracking_id )
LEFT JOIN
(
select hub_id,tracking_id,scanned_date_time,bag_weight,rank, 
machine_id,
hub_type,
machine_status,
weight_entry_type,
is_within_tolerance
from
(select data.hub_id,
data.tracking_id,
data.scanned_date_time,
data.bag_weight,
data.machine_id,
data.hub_type,
data.machine_status,
data.weight_entry_type,
data.is_within_tolerance,
ROW_NUMBER() OVER (PARTITION BY data.tracking_id ORDER BY data.scanned_date_time ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)  as rank
from bigfoot_journal.dart_wsr_scp_ekl_weighthistory_1 ) as d1 where d1.rank=4) as d
on (d.tracking_id=x.tracking_id )

LEFT JOIN
(
select hub_id,tracking_id,scanned_date_time,bag_weight,rank ,
machine_id,
hub_type,
machine_status,
weight_entry_type,
is_within_tolerance
from
(select data.hub_id,
data.tracking_id,
data.scanned_date_time,
data.bag_weight,
data.machine_id,
data.hub_type,
data.machine_status,
data.weight_entry_type,
data.is_within_tolerance,
ROW_NUMBER() OVER (PARTITION BY data.tracking_id ORDER BY data.scanned_date_time DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)  as rank
from bigfoot_journal.dart_wsr_scp_ekl_weighthistory_1  ) as a1 where a1.rank=1) as dest
on dest.tracking_id=b.data.vendor_tracking_id
left join
(
select count(distinct vendor_tracking_id) as no_of_shipments_inscanned,incoming_bag_tracking_id,incoming_bag_destination_hub_id from bigfoot_external_neo.scp_ekl__shipment_facility_l2_90_fact
where shipment_facility_inscan_datetime is not null
group by incoming_bag_tracking_id,incoming_bag_destination_hub_id
) as bs
on bs.incoming_bag_tracking_id=dest.tracking_id and bs.incoming_bag_destination_hub_id=dest.hub_idTABLE consignment_l1_90_fact
-- changed the actial eta to consignment receive time for calculating consignment eta breach line#17consignment_breach_flag
-- changed the eta breach definition to eta < consignment receive time line#18consignment_breach_flag
-- Added ekl_zone for movement flag
-- changed conecction_1_11 to connection_1
-- Changed eta datetime from max to min
SELECT CAST(SPLIT(Cons.entityid, "-")[1] AS INT) AS consignment_id,
       Cons.`data`.vendor_tracking_id AS consignment_awb_number,
       Cons.`data`.connection_id AS consignment_connection_id,
       IF(size(Cons.`data`.shipment_groups)>0,'BAG','SHIPMENT') AS consignment_type,
       upper(Cons.`data`.connection_mode) AS consignment_mode,
       Conn.`data`.type AS connection_type,
       Conn.`data`.transit_type AS connection_transit_type,
       Conn.`data`.code AS connection_code,
       Conn.`data`.frequency_type AS connection_frequency_type,
       Conn.`data`.vehicle_no AS connection_vehicle_no,
       Cons.`data`.status AS consignment_status,
       Cons.`data`.source_location.type AS consignment_source_hub_type,
       Cons.`data`.destination_location.type AS consignment_destination_hub_type,
       Conn.`data`.coloader AS consignment_co_loader,
	   if(consign.consignment_received_datetime is not null,if(unix_timestamp(consign.consignment_received_datetime)> unix_timestamp(consign.eta),1,0),If(unix_timestamp()>(unix_timestamp(consign.eta)),1,0)) as consignment_breach_flag,
	   
	   IF((upper(src_hub.lt) = upper(dest_hub.lt) OR upper(src_hub.city)=upper(dest_hub.city)), "INTRACITY"
			,IF(upper(src_hub.geo_zone) = upper(dest_hub.geo_zone), "INTRAZONE"
				, IF(upper(src_hub.geo_zone) <> upper(dest_hub.geo_zone), "INTERZONE", "Missing")
				)
		) as consignment_movement_flag,
       size(Cons.`data`.shipment_groups) AS consignment_no_of_bags,
       size(Cons.`data`.shipments) AS consignment_no_of_shipments,
       CAST(IF(Cons.`data`.connection_id=0,0,1) AS INT) AS tms_compliant_consignments,
       CAST(IF(Cons.`data`.connection_id=0,0,size(Cons.`data`.shipment_groups)) AS INT) AS tms_compliant_bags,
       CAST(IF(Cons.`data`.connection_id=0,0,size(Cons.`data`.shipments)) AS INT) AS tms_compliant_shipments,
       Cons.`data`.source_location.id AS consignment_source_hub_id,
       Cons.`data`.destination_location.id AS consignment_destination_hub_id,
       0.0 AS consignment_lane_cost_per_kg,
       0.0 AS consignment_n_form_charges,
       Cons.`data`.system_weight.physical AS consignment_system_weight,
       Cons.`data`.sender_weight.physical AS consignment_sender_measured_weight,
       Cons.`data`.receiver_weight.physical AS consignment_receiver_measured_weight,
       CAST(IF(Cons.`data`.system_weight.physical > Cons.`data`.system_weight.volumetric, Cons.`data`.system_weight.physical, Cons.`data`.system_weight.volumetric) AS DOUBLE) AS consignment_chargeable_weight,
       Cons.`data`.created_at AS consignment_create_datetime,
       consign.consignment_received_datetime as consignment_received_datetime,
       CAST((Cons.updatedat/1000) AS TIMESTAMP) AS consignment_status_date_time,
       CAST(If((Hour(Cons.`data`.created_at)*60*60+Minute(Cons.`data`.created_at)*60+Second(Cons.`data`.created_at))<Conn.`data`.cutoff-60*60,
              (Conn.`data`.cutoff+round(unix_timestamp(Cons.`data`.created_at)/86400)*86400-19800-86400),(Conn.`data`.cutoff+round(unix_timestamp(Cons.`data`.created_at)/86400)*86400-19800)) AS TIMESTAMP) AS connection_cut_off_datetime,
       (Unix_timestamp(Cons.`data`.created_at)-If((Hour(Cons.`data`.created_at)*60*60+Minute(Cons.`data`.created_at)*60+Second(Cons.`data`.created_at))<Conn.`data`.cutoff-60*60,
              (Conn.`data`.cutoff+round(unix_timestamp(Cons.`data`.created_at)/86400)*86400-(19800+86400)),(Conn.`data`.cutoff+round(unix_timestamp(Cons.`data`.created_at)/86400)*86400-19800)))/3600 AS consignment_creation_delay_in_hours,
       CAST((unix_timestamp() - unix_timestamp(Cons.`data`.created_at))/(3600) AS INT) AS consignment_total_age_in_hours,
       COALESCE (cast(consign.eta as string),from_unixtime(unix_timestamp(Cons.`data`.created_at)+Cons.`data`.connection_estimated_tat)) AS consignment_eta_datetime,
       (Cons.`data`.connection_estimated_tat-If(Cons.`data`.connection_actual_tat IS NULL OR Cons.`data`.connection_actual_tat = 0,
              Hour(from_unixtime(unix_timestamp()))*60*60+Minute(from_unixtime(unix_timestamp()))*60+Second(from_unixtime(unix_timestamp())),
              Cons.`data`.connection_actual_tat))/3600 AS consignment_receive_delay_in_hours,
       CAST(IF(Cons.`data`.connection_id=0,size(Cons.`data`.shipment_groups),0) AS INT) AS tms_non_compliant_bags,
       CAST(IF(Cons.`data`.connection_id=0,size(Cons.`data`.shipments),0) AS INT) AS tms_non_compliant_shipments,bagcons.`data`.bag_based_reason as bag_based_consignment_reason,
	   consign.eta as eta
FROM bigfoot_snapshot.dart_wsr_scp_ekl_shipmentgroup_3_view Cons
inner join 
(select 
    CAST(SPLIT(entityid, "-")[1] AS INT) AS consignment_id,
	min(struct(updatedat, data.eta)).col2 as eta,
    min(IF(`data`.status='Received', CAST((updatedat/1000) AS TIMESTAMP), NULL)) as consignment_received_datetime
    from bigfoot_journal.dart_wsr_scp_ekl_shipmentgroup_3 where day > date_format(date_sub(current_date,100),'yyyyMMdd')
    group by CAST(SPLIT(entityid, "-")[1] AS INT)
) consign
on CAST(SPLIT(Cons.entityid, "-")[1] AS INT)=consign.consignment_id
LEFT OUTER JOIN  
(	SELECT facility.facility_id as facility_id,
	ekl_hive_facility_dim_key,
	`data`.local_territory as lt, 
	`data`.city   AS city,
	`data`.zone   AS geo_zone,
	`data`.state  AS geo_state,
	facility.postal_code				
	FROM bigfoot_external_neo.scp_ekl__ekl_hive_facility_dim  as facility 
	JOIN bigfoot_snapshot.dart_fki_scp_ekl_geo_1_view_total AS geo 
	ON   geo.`data`.pincode=facility.postal_code
) as src_hub
on lookupkey('facility_id', Cons.`data`.source_location.id)=src_hub.ekl_hive_facility_dim_key
LEFT OUTER JOIN  
(	SELECT facility.facility_id as facility_id, 
	ekl_hive_facility_dim_key,
	`data`.local_territory as lt, 
	`data`.city   AS city,
	`data`.zone   AS geo_zone,
	`data`.state  AS geo_state,
	facility.postal_code				
	FROM bigfoot_external_neo.scp_ekl__ekl_hive_facility_dim  as facility 
	JOIN bigfoot_snapshot.dart_fki_scp_ekl_geo_1_view_total AS geo 
	ON   geo.`data`.pincode=facility.postal_code
) as dest_hub 
on lookupkey('facility_id', Cons.`data`.destination_location.id)=dest_hub.ekl_hive_facility_dim_key
LEFT OUTER JOIN bigfoot_snapshot.dart_wsr_scp_ekl_connection_1_view_total Conn ON Cons.`data`.connection_id = cast(split(Conn.entityid, "-")[1] AS INT)
LEFT OUTER JOIN bigfoot_journal.dart_wsr_scp_ekl_bagbasedconsignmentdata_1 bagcons
on bagcons.`data`.consignment_id=consign.consignment_id
WHERE Cons.`data`.type = 'consignment';