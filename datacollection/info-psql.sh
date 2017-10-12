#!/bin/bash
## Script información de PostgreSQL ## 
### Hecho por Francis Santiago ###
echo '
                         _
███████╗ █████╗ ███╗   ██╗ ██████╗███████╗ ██████╗
██╔════╝██╔══██╗████╗  ██║██╔════╝██╔════╝██╔════╝
███████╗███████║██╔██╗ ██║██║     █████╗  ██║     
╚════██║██╔══██║██║╚██╗██║██║     ██╔══╝  ██║     
███████║██║  ██║██║ ╚████║╚██████╗██║     ╚██████╗
╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚═╝      ╚═════╝
                                              
Consultora: Francis Santiago 
Descripción: Este  Script  se encarga de recolectar información de las Base de Datos de PostgreSQL
' 


echo "Favor introduzca la clave del usuario postgres " 
read -s -p "Password: " Pass 

export PGPASSWORD="$Pass"

echo -e "\nFavor introduzca Nombre del Cliente" 
read -p "Cliente: " Cliente
echo -e "\nFavor introduzca Puerto de Postgres" 
read -p "Puerto: "  puerto
echo -e "\nFavor introduzca ip del Host" 
read -p "Host: " host

H=$host
P=$puerto
U=postgres
C=$Cliente
Path=~/Inf_Bds_$C
DBd=$Path/datos_bds
DC=$Path/datos_comunes
### Crear Carpetas para Información  ## 


mkdir -p  $DBd

mkdir -p  $DC

## Valores de la Bds ## 

echo 'Recopilando informacion General de la Bds' 

echo 'Recopilando informacion de los tamaños de las Bds' 

psql -h $H  -U $U  -c "select datname,(pg_database_size(datname)/1024)/1024 as tamanoMB from pg_database where datname not in ('template1','template0','postgres') "  >  $DC/databases_work.txt

echo 'Recopilando informacion de la actividad de Usuarios' 

psql -h $H  -U $U  -c "select * from pg_stat_activity" | sed '2d' >  $DC/activity_bds.csv
psql -h $H  -U $U  -c "select * from pg_stat_activity" -H >  $DC/activity_bds.html
psql -h $H  -U $U  -l  >  $DC/bds_owner.csv
psql -h $H  -U $U  -l -H >  $DC/bds_owner.html
echo 'Recopilando informacion de la actividad de cada Base de Datos' 

psql -h $H  -U $U  -c "select * from pg_stat_database where datname<>'postgres' and datname not like 'template%'" -H > $DC/db_estadistica_global.html

psql -h $H  -U $U  -c "SELECT datname, numbackends as CONN, xact_commit as TX_COMM,xact_rollback as TX_RLBCK, blks_read + blks_hit as READ_TOTAL,blks_read ,blks_hit, case when blks_read + blks_hit = 0 then 0 else blks_hit * 100 /  (blks_read + blks_hit)end as BUFFER FROM pg_stat_database where datname<>'postgres' and datname not like 'template%'" -H > $DC/db_buffer_use.html
psql -h $H  -U $U  -c "SELECT datname, numbackends as CONN, xact_commit as TX_COMM,xact_rollback as TX_RLBCK, blks_read + blks_hit as READ_TOTAL,blks_read ,blks_hit, case when blks_read + blks_hit = 0 then 0 else blks_hit * 100 /  (blks_read + blks_hit)end as BUFFER FROM pg_stat_database where datname<>'postgres' and datname not like 'template%'"  > $DC/db_buffer_use.csv
psql -h $H $i -U $U  -c "SELECT spcname,round(  (pg_tablespace_size(spcname)/1024)/1024,2) tamanoMB , pg_tablespace_location(oid) as ubicacion FROM pg_tablespace" | sed '2d' > $DC/inf_tablespace.csv
psql -h $H $i -U $U  -c "SELECT spcname,round(  (pg_tablespace_size(spcname)/1024)/1024,2) tamanoMB , pg_tablespace_location(oid) as ubicacion FROM pg_tablespace" -H > $DC/inf_tablespace.html


##  Crear las carpetas por BDs ## 
echo 'Creando directorios' 

cat $DC/databases_work.txt | sed '/^$/d' | sed '/./!d' | sed '1,2d;$d' | awk '{print $1}' | xargs  -I{} mkdir ${DBd}/{}


## Comandos por Base de Datos ### 

Bds=`psql -U postgres -h $H -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d'`

#Recorrer todas las bases

echo 'Empezando a recopilar Informacion por Bds' 

for i in $Bds; do

if [ "$i" != "template0" ] && [ "$i" != "template1" ] && [ "$i" != "postgres" ]; then

echo 'Recopilando informacion de las BBDD:' $i

psql -h $H $i -U $U  -c "SELECT idstat.relname AS table_name, indexrelname AS index_name,idstat.idx_scan AS times_used,n_tup_upd + n_tup_ins + n_tup_del as num_writes,indexdef AS definition  FROM pg_stat_user_indexes AS idstat JOIN pg_indexes ON indexrelname=indexname JOIN pg_stat_user_tables AS tabstat ON idstat.relname = tabstat.relname  ORDER BY idstat.relname, indexrelname;" -H > $DBd/$i/inf_index.html
psql -h $H $i -U $U  -c "SELECT idstat.relname AS table_name, indexrelname AS index_name,idstat.idx_scan AS times_used,n_tup_upd + n_tup_ins + n_tup_del as num_writes,indexdef AS definition  FROM pg_stat_user_indexes AS idstat JOIN pg_indexes ON indexrelname=indexname JOIN pg_stat_user_tables AS tabstat ON idstat.relname = tabstat.relname  ORDER BY idstat.relname, indexrelname;" | sed '2d' > $DBd/$i/inf_index.csv
psql -h $H $i -U $U  -c "SELECT nm.nspname,proname,tp.typname, pr.prosrc,calls,total_time,self_time FROM pg_proc pr join  pg_type tp on (tp.oid = pr.prorettype)   left join pg_stat_user_functions pgst on (pr.oid = pgst.funcid) join pg_namespace nm on ( pr.pronamespace = nm.oid) WHERE    pr.proisagg = FALSE       AND pr.pronamespace IN (  SELECT oid    FROM pg_namespace  WHERE nspname NOT LIKE 'pg_%'  AND nspname != 'information_schema'  ) " -H > $DBd/$i/inf_funciones.html
psql -h $H $i -U $U  -c "SELECT nm.nspname,proname,tp.typname, pr.prosrc,calls,total_time,self_time FROM pg_proc pr join  pg_type tp on (tp.oid = pr.prorettype)   left join pg_stat_user_functions pgst on (pr.oid = pgst.funcid) join pg_namespace nm on ( pr.pronamespace = nm.oid) WHERE    pr.proisagg = FALSE       AND pr.pronamespace IN (  SELECT oid    FROM pg_namespace  WHERE nspname NOT LIKE 'pg_%'  AND nspname != 'information_schema'  ) " | sed '2d' > $DBd/$i/inf_funciones.csv
psql -h $H $i -U $U  -c "SELECT idstat.schemaname,idstat.relname AS table_name,indexrelname AS index_name,idstat.idx_scan AS times_used,idstat.idx_tup_read,idstat.idx_tup_fetch,round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::text || ' MB' AS index_size FROM pg_stat_user_indexes AS idstat  JOIN pg_stat_user_tables AS tabstat ON idstat.relname = tabstat.relname WHERE idstat.idx_scan=0 ORDER BY 4 desc" | sed '2d' > $DBd/$i/inf_indx_sinuso.csv
psql -h $H $i -U $U  -c "SELECT idstat.schemaname,idstat.relname AS table_name,indexrelname AS index_name,idstat.idx_scan AS times_used,idstat.idx_tup_read,idstat.idx_tup_fetch,round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::text || ' MB' AS index_size FROM pg_stat_user_indexes AS idstat  JOIN pg_stat_user_tables AS tabstat ON idstat.relname = tabstat.relname WHERE idstat.idx_scan=0 ORDER BY 4 desc" -H > $DBd/$i/inf_indx_sinuso.html
psql -h $H $i -U $U  -c "SELECT idstat.schemaname,idstat.relname AS table_name,indexrelname AS index_name,idstat.idx_scan AS times_used,idstat.idx_tup_read,idstat.idx_tup_fetch,round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::text || ' MB' AS index_size FROM pg_stat_user_indexes AS idstat  JOIN pg_stat_user_tables AS tabstat ON idstat.relname = tabstat.relname WHERE idstat.idx_scan=0 AND position('UNIQUE' in pg_get_indexdef(indexrelid))<>0   ORDER BY 4 desc" -H > $DBd/$i/inf_indx_unique.html
psql -h $H $i -U $U  -c "SELECT idstat.schemaname,idstat.relname AS table_name,indexrelname AS index_name,idstat.idx_scan AS times_used,idstat.idx_tup_read,idstat.idx_tup_fetch,round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::text || ' MB' AS index_size FROM pg_stat_user_indexes AS idstat  JOIN pg_stat_user_tables AS tabstat ON idstat.relname = tabstat.relname WHERE idstat.idx_scan=0 AND position('UNIQUE' in pg_get_indexdef(indexrelid))<>0   ORDER BY 4 desc"  | sed '2d' > $DBd/$i/inf_indx_unique.csv
psql -h $H $i -U $U  -c "select nspname,relname,COALESCE(pg_tablespace.spcname,(select pg_tablespace.spcname   from pg_database,pg_tablespace where   dattablespace=pg_tablespace.oid and datname=current_database())) as table_space from pg_class left join pg_tablespace on (reltablespace=pg_tablespace.oid) join pg_namespace on  (pg_class.relnamespace=pg_namespace.oid) where nspname <> 'pg_catalog' and nspname <> 'information_schema' and nspname <> 'pg_toast'  and  relkind='i'" -H > $DBd/$i/inf_indx_tablespace.html
psql -h $H $i -U $U  -c "select nspname,relname,COALESCE(pg_tablespace.spcname,(select pg_tablespace.spcname   from pg_database,pg_tablespace where   dattablespace=pg_tablespace.oid and datname=current_database())) as table_space from pg_class left join pg_tablespace on (reltablespace=pg_tablespace.oid) join pg_namespace on  (pg_class.relnamespace=pg_namespace.oid) where nspname <> 'pg_catalog' and nspname <> 'information_schema' and nspname <> 'pg_toast'  and  relkind='i'" | sed '2d'  > $DBd/$i/inf_indx_tablespace.csv
psql -h $H $i -U $U  -c "(SELECT ns.nspname as schema,(select count (*)  from pg_tables where schemaname=ns.nspname) as cantidad_tablas,(select count(*) from pg_indexes where schemaname=ns.nspname) as cantidad_indices, (with vi as (select count (*) as cantidad from pg_catalog.pg_views where schemaname NOT IN ('pg_catalog', 'information_schema') and schemaname=ns.nspname union all select count(*) from pg_matviews   where schemaname <> 'pg_catalog' and schemaname <> 'information_schema'and schemaname=ns.nspname )  select sum(cantidad) as cantidad_vistas from vi),
(SELECT count(*) FROM pg_proc pr join  pg_type tp on (tp.oid = pr.prorettype)   left join pg_stat_user_functions pgst on (pr.oid  = pgst.funcid) join pg_namespace nm on ( pr.pronamespace= nm.oid) WHERE    pr.proisagg = FALSE       AND pr.pronamespace IN (  SELECT oid    FROM pg_namespace  WHERE nspname NOT LIKE 'pg_%'  AND nspname !='information_schema' AND nspname=ns.nspname) ) as cantidad_funciones,(select  count(*) from information_schema.triggers where trigger_schema=ns.nspname) as cantidad_triggers,COALESCE(sum (round((pg_relation_size(psat.relid::regclass)/1024)/1024::numeric,2)::real),0 )as peso_tabla,COALESCE( sum( round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::real),0) AS peso_index FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname) join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) left join pg_stat_user_indexes AS idstat ON idstat.relname = psat.relname group by 1  ORDER BY 2 DESC) union all (SELECT 'Total' , (select count (*)  from pg_tables where schemaname NOT IN ('pg_catalog', 'information_schema') ) as cantidad_tablas,( select count(*) from pg_indexes where schemaname NOT IN ('pg_catalog', 'information_schema')) as cantidad_indices, (with vitotal as (select count (*) as cantidad from pg_catalog.pg_views where schemaname NOT IN ('pg_catalog', 'information_schema') union all select count(*) from pg_matviews   where schemaname <> 'pg_catalog' and schemaname <> 'information_schema'  ) select sum (cantidad) from vitotal),(SELECT count(*) FROM pg_proc pr join  pg_type tp on (tp.oid = pr.prorettype)   left join pg_stat_user_functions pgst on (pr.oid  = pgst.funcid) join pg_namespace nm on ( pr.pronamespace= nm.oid) WHERE    pr.proisagg = FALSE       AND pr.pronamespace IN (  SELECT oid    FROM pg_namespace  WHERE nspname NOT LIKE 'pg_%'  AND nspname !='information_schema' ) ) as cantidad_funciones,(select  count(*) from information_schema.triggers ) as cantidad_triggers,sum (round((pg_relation_size(psat.relid::regclass)/1024)/1024::numeric,2)::real) as peso_tabla,sum( round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::real) AS peso_index FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname) join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) left join pg_stat_user_indexes AS idstat ON idstat.relname = psat.relname)" -H > $DBd/$i/inf_esquemas.html
psql -h $H $i -U $U  -c "(SELECT ns.nspname as schema,(select count (*)  from pg_tables where schemaname=ns.nspname) as cantidad_tablas,(select count(*) from pg_indexes where schemaname=ns.nspname) as cantidad_indices, (with vi as (select count (*) as cantidad from pg_catalog.pg_views where schemaname NOT IN ('pg_catalog', 'information_schema') and schemaname=ns.nspname union all select count(*) from pg_matviews   where schemaname <> 'pg_catalog' and schemaname <> 'information_schema'and schemaname=ns.nspname )  select sum(cantidad) as cantidad_vistas from vi),
(SELECT count(*) FROM pg_proc pr join  pg_type tp on (tp.oid = pr.prorettype)   left join pg_stat_user_functions pgst on (pr.oid  = pgst.funcid) join pg_namespace nm on ( pr.pronamespace= nm.oid) WHERE    pr.proisagg = FALSE       AND pr.pronamespace IN (  SELECT oid    FROM pg_namespace  WHERE nspname NOT LIKE 'pg_%'  AND nspname !='information_schema' AND nspname=ns.nspname) ) as cantidad_funciones,(select  count(*) from information_schema.triggers where trigger_schema=ns.nspname) as cantidad_triggers,COALESCE(sum (round((pg_relation_size(psat.relid::regclass)/1024)/1024::numeric,2)::real),0 )as peso_tabla,COALESCE( sum( round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::real),0) AS peso_index FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname) join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) left join pg_stat_user_indexes AS idstat ON idstat.relname = psat.relname group by 1  ORDER BY 2 DESC) union all (SELECT 'Total' , (select count (*)  from pg_tables where schemaname NOT IN ('pg_catalog', 'information_schema') ) as cantidad_tablas,( select count(*) from pg_indexes where schemaname NOT IN ('pg_catalog', 'information_schema')) as cantidad_indices, (with vitotal as (select count (*) as cantidad from pg_catalog.pg_views where schemaname NOT IN ('pg_catalog', 'information_schema') union all select count(*) from pg_matviews   where schemaname <> 'pg_catalog' and schemaname <> 'information_schema'  ) select sum (cantidad) from vitotal),(SELECT count(*) FROM pg_proc pr join  pg_type tp on (tp.oid = pr.prorettype)   left join pg_stat_user_functions pgst on (pr.oid  = pgst.funcid) join pg_namespace nm on ( pr.pronamespace= nm.oid) WHERE    pr.proisagg = FALSE       AND pr.pronamespace IN (  SELECT oid    FROM pg_namespace  WHERE nspname NOT LIKE 'pg_%'  AND nspname !='information_schema' ) ) as cantidad_funciones,(select  count(*) from information_schema.triggers ) as cantidad_triggers,sum (round((pg_relation_size(psat.relid::regclass)/1024)/1024::numeric,2)::real) as peso_tabla,sum( round((pg_relation_size(idstat.indexrelid::regclass)/1024)/1024::numeric,2)::real) AS peso_index FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname) join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) left join pg_stat_user_indexes AS idstat ON idstat.relname = psat.relname)"  > $DBd/$i/inf_esquemas.csv
psql -h $H $i -U $U  -c "SELECT trigger_schema,trigger_name,event_manipulation,action_timing,event_object_schema,event_object_table,action_statement from information_schema.triggers order by 4 desc " -H > $DBd/$i/inf_trigger.html
psql -h $H $i -U $U  -c "SELECT trigger_schema,trigger_name,event_manipulation,action_timing,event_object_schema,event_object_table,action_statement from information_schema.triggers order by 4 desc" | sed '2d' > $DBd/$i/inf_trigger.csv
psql -h $H $i -U $U  -c "select schemaname, viewname,'Normal' as type,definition from pg_views  where schemaname <> 'pg_catalog' and schemaname <> 'information_schema' union all select schemaname, matviewname,'Mat',definition from pg_matviews   where schemaname <> 'pg_catalog' and schemaname <> 'information_schema'" -H > $DBd/$i/inf_vistas.html
psql -h $H $i -U $U  -c "select schemaname, viewname,'Normal' as type,definition from pg_views  where schemaname <> 'pg_catalog' and schemaname <> 'information_schema' union all select schemaname, matviewname,'Mat',definition from pg_matviews   where schemaname <> 'pg_catalog' and schemaname <> 'information_schema'" | sed '2d' > $DBd/$i/inf_vistas.csv
psql -h $H $i -U $U  -c "SELECT ns.nspname||'.'|| pg.relname as name , reltuples::int ,round((pg_relation_size(psat.relid::regclass)/1024)/1024::numeric,2)::text || ' MB' as Weigth,n_live_tup,n_dead_tup,psat.seq_scan,psat.seq_tup_read,COALESCE( psat.idx_scan,0) as index_scan , COALESCE( psat.idx_tup_fetch,0) as index_fetch,n_tup_ins,n_tup_del,n_tup_upd FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname)join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) ORDER BY 2 DESC" -H > $DBd/$i/inf_datos_tablas.html
psql -h $H $i -U $U  -c "SELECT ns.nspname||'.'|| pg.relname as name , reltuples::int ,round((pg_relation_size(psat.relid::regclass)/1024)/1024::numeric,2)::text || ' MB' as Weigth,n_live_tup,n_dead_tup,psat.seq_scan,psat.seq_tup_read,COALESCE( psat.idx_scan,0) as index_scan , COALESCE( psat.idx_tup_fetch,0) as index_fetch,n_tup_ins,n_tup_del,n_tup_upd FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname)join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) ORDER BY 2 DESC"  > $DBd/$i/inf_datos_tablas.csv
psql -h $H $i -U $U  -c " SELECT ns.nspname||'.'|| pg.relname as name , psat.n_dead_tup, autovacuum_count,COALESCE( to_char(last_autovacuum,'YYYY:MM:DD-HH24:MI:SS'),'-') as fecha_last_auto,vacuum_count,COALESCE(to_char(last_vacuum,'YYYY:MM:DD-HH24:MI:SS'),'-' ) as fecha_last_vac , analyze_count,COALESCE( to_char(last_analyze,'YYYY:MM:DD-HH24:MI:SS'),'-') as last_analyze,autoanalyze_count,COALESCE( to_char(last_autoanalyze,'YYYY:MM:DD-HH24:MI:SS'),'-') as last_auto_analyze,age(relfrozenxid)  FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname)  join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) ORDER BY 2 DESC;" -H > $DBd/$i/inf_datos_tablas_mant.html
psql -h $H $i -U $U  -c " SELECT ns.nspname||'.'|| pg.relname as name , psat.n_dead_tup, autovacuum_count,COALESCE( to_char(last_autovacuum,'YYYY:MM:DD-HH24:MI:SS'),'-') as fecha_last_auto,vacuum_count,COALESCE(to_char(last_vacuum,'YYYY:MM:DD-HH24:MI:SS'),'-' ) as fecha_last_vac , analyze_count,COALESCE( to_char(last_analyze,'YYYY:MM:DD-HH24:MI:SS'),'-') as last_analyze,autoanalyze_count,COALESCE( to_char(last_autoanalyze,'YYYY:MM:DD-HH24:MI:SS'),'-') as last_auto_analyze,age(relfrozenxid)  FROM pg_class pg JOIN pg_stat_user_tables psat ON (pg.relname = psat.relname)  join pg_namespace a on ( pg.relnamespace = a.oid)  join pg_namespace ns  on (pg.relnamespace = ns.oid) ORDER BY 2 DESC;"  > $DBd/$i/inf_datos_tablas_mant.csv
##psql -h $H $i -U $U  -c "" -H > $DBd/$i/inf_indx_sinuso.html
##psql -h $H $i -U $U  -c "" -H > $DBd/$i/inf_indx_sinuso.html
##pg_dump -h $H $i -U  $U -C -s > $DBd/$i/inf_estructuraBD.txt

fi
done
## Archivo de Configuración ## 
psql -h $H $i -U $U  -c "select * from pg_settings order by 4" -H > $DC/conf_orig.html
psql -h $H $i -U $U  -c "select name,setting from pg_settings " | sed '2d' > $DC/conf_orig.csv
psql -h $H $i -U $U  -c "SELECT * FROM pg_settings WHERE source != 'default' AND source != 'override'ORDER by 2, 1" -H > $DC/conf_mod.html
psql -h $H $i -U $U  -c "SELECT name, setting FROM pg_settings WHERE source != 'default' AND source != 'override'ORDER by 2, 1"  | sed '2d'> $DC/conf_mod.csv

pg_dumpall  -h $H  -U $U -s > $DC/estructura_bds.txt
pg_dumpall  -h $H  -U $U -r > $DC/roles_bds.txt

### Información del Servidor  ###

echo "Información del Servidor"

touch $DC/datosSO.txt
echo "Version SO" > $DC/datosSO.txt
cat /etc/redhat-release >> $DC/datosSO.txt
echo -e  "\n" >> $DC/datosSO.txt
echo "Nombre Servidor" >> $DC/datosSO.txt
hostname >> $DC/datosSO.txt
echo -e  "\n" >> $DC/datosSO.txt
echo "Interfaces de Red" >> $DC/datosSO.txt
ip addr show | grep "inet"    | awk  '{print $2,$7}' | cut -f1 -d":" | sed '1d'| sed '1d' | sed '2d' | sed '3d' >> $DC/datosSO.txt
echo -e  "\n" >> $DC/datosSO.txt
echo "Memoria del Servidor" >> $DC/datosSO.txt
free -g  >> $DC/datosSO.txt
echo -e  "\n" >> $DC/datosSO.txt
echo "Particiones" >> $DC/datosSO.txt
df -h >> $DC/datosSO.txt
echo -e  "\n" >> $DC/datosSO.txt
echo "Información Procesadores" >> $DC/datosSO.txt
grep processor /proc/cpuinfo | wc -l >> $DC/datosSO.txt
cat /proc/cpuinfo | grep "model name" >> $DC/datosSO.txt
cat /proc/cpuinfo | grep "cpu cores">> $DC/datosSO.txt


########################################################################################
########################################################################################
########################## GENERAR INFORME HTML ########################################
########################################################################################
########################################################################################

SO=`cat /etc/redhat-release`
TBD=` psql -h $H $i -U $U  -c "select count(*) from pg_database where datname<>'postgres' and datname not like 'template%'" | tail -n+3 |head -n1 `
TTABLESPACE=`psql -h $H $i -U $U  -c "SELECT count(*) FROM pg_tablespace where spcname  not like 'pg_%' " | tail -n+3 |head -n1 `
VPSQL=`psql --version | cut -d" " -f2-3`
TUSU=`  psql -h $H $i -U $U  -c "SELECT count(*) FROM pg_roles where rolname <>'postgres'" | tail -n+3 |head -n1 `
DESC="Revisar las las base de datos para mejorar el rendimiento en velocidad, espacio y funcionalidad"
FECHA=`date +%d/%m/%Y`

###HTML
style_td="style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='center'"
style_td2="style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' height='17' align='left'"
echo "
<html>

<body>
<br><br>
<table cellspacing="0" border="0"> <colgroup width="85"></colgroup> <colgroup width="132"></colgroup>	<colgroup width="101"></colgroup>	<colgroup width="60"></colgroup> <colgroup width="70"></colgroup> <colgroup width="81"></colgroup> <colgroup width="85"></colgroup> <colgroup width="87"></colgroup>
	<tr>
		<td height="17" align="left"><br></td>
		<td align="left">SANCFC</td>
		<td align="left"><br></td>
		<td align="left">Santiago:</td>
		<td align="left">$FECHA<br></td>
		<td align="left"><br></td>
		<td align="left"><br></td>
		<td align="left"><br></td>
	</tr>

</table>


<br><br>

<table cellspacing="0" border="0"> 
<colgroup width="85"></colgroup> <colgroup width="132"></colgroup>   <colgroup width="160"></colgroup>
<colgroup width="160"></colgroup> <colgroup width="70"></colgroup>
<colgroup width="81"></colgroup> <colgroup width="85"></colgroup> <colgroup width="87"></colgroup>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=2 rowspan=6 height='128' align='center' valign=middle><br></td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='left'>Cliente:</td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=3 align='center' valign=middle>$C</td>
	</tr>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='left'>SO:</td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=3 align='center' valign=middle>$SO</td>
	</tr>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='left'>Base de Datos:</td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=3 align='center' valign=middle>$TBD</td>
	</tr>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='left'>Tablespace:</td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=3 align='center' valign=middle>$TTABLESPACE</td>
	</tr>

	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='left'>Version PSQL</td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=3 align='center' valign=middle>$VPSQL</td>
	</tr>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='left'>Usuarios:</td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=3 align='center' valign=middle>$TUSU</td>
	</tr>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' align='left'>Descripcion:</td>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=3 align='center' valign=middle>$DESC</td>
	</tr>
</table>


<br><br>


<table cellspacing="0" border="0"> <colgroup width="85"></colgroup> <colgroup width="132"></colgroup>   <colgroup width="101"></colgroup>       <colgroup width="60"></colgroup> <colgroup width="70"></colgroup> <colgroup width="81"></colgroup> <colgroup width="85"></colgroup> <colgroup width="87"></colgroup>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' colspan=9 height='17' align='center' valign=middle><b>Informacion de las Base de Datos</b></td>
		</tr>
	<tr>
		<td style='border-top: 1px solid #000000; border-bottom: 1px solid #000000; border-left: 1px solid #000000; border-right: 1px solid #000000' height='17' align='center'><b> Nombre </b></td>
		<td $style_td><b> Peso </b></td>
		<td $style_td><b> Tablas </b></td>
		<td $style_td><b> Esquemas </b></td>
		<td $style_td><b> Funciones </b></td>
		<td $style_td><b> Triggers </b></td>
		<td $style_td><b> Indices </b></td>
		<td $style_td><b> Vistas </b></td>
	</tr>

" >$DC/info-`date +%d%m%Y`.html

##################################################### INF PRO BD

for i in $Bds; do

if [ "$i" != "template0" ] && [ "$i" != "template1" ] && [ "$i" != "postgres" ]; then

PESO=`psql -h $H $i -U $U  -c "select (pg_database_size(datname)/1024)/1024 as tamanoMB from pg_database where  datname = '$i'" | tail -n+3 |head -n1 `
TTABLA=`psql -h $H $i -U $U  -c "SELECT count(*) FROM pg_tables where tablename not like 'pg_%'  and schemaname <>'information_schema'" | tail -n+3 |head -n1 ` 
TESQUEMA=`psql -h $H $i -U $U  -c "select count(*) from pg_namespace where nspname not like 'pg_%'  and nspname <>'information_schema'" | tail -n+3 |head -n1 `
TFUNCIONES=`psql -h $H $i -U $U  -c "SELECT count(*) FROM pg_proc pr join  pg_type tp on (tp.oid = pr.prorettype)   left join pg_stat_user_functions pgst on (pr.oid = pgst.funcid) join pg_namespace nm on ( pr.pronamespace= nm.oid) WHERE    pr.proisagg = FALSE       AND pr.pronamespace IN (  SELECT oid    FROM pg_namespace  WHERE nspname NOT LIKE 'pg_%'  AND nspname !='information_schema')" | tail -n+3 |head -n1 `
TTRIGGERS=`psql -h $H $i -U $U  -c "SELECT count(*) from information_schema.triggers" | tail -n+3 |head -n1 `
TINDICES=`psql -h $H $i -U $U  -c "select count(*) from pg_indexes where schemaname not like 'pg_%'" | tail -n+3 |head -n1 `
TVISTA=`psql -h $H $i -U $U  -c "select sum(count) AS Total_VS from ( select count(*)from pg_views  where schemaname <> 'pg_catalog' and schemaname <> 'information_schema' union all select count(*) from pg_matviews where schemaname <> 'pg_catalog' and schemaname <> 'information_schema' ) as total" | tail -n+3 |head -n1 `



echo "

	<tr>
		<td $style_td2><b>$i</b></td>
		<td $style_td2><b>$PESO</b></td>
		<td $style_td2><b>$TTABLA</b></td>
		<td $style_td2><b>$TESQUEMA</b></td>
		<td $style_td2><b>$TFUNCIONES</b></td>
		<td $style_td2><b>$TTRIGGERS</b></td>
		<td $style_td2><b>$TINDICES</b></td>
		<td $style_td2><b>$TVISTA</b></td>
	</tr>

" >> $DC/info-`date +%d%m%Y`.html


fi
done




##################################################### END
echo "

</table>
</body>

</html>" >> $DC/info-`date +%d%m%Y`.html

echo "Comprimiendo los Archivos"

tar czf  ~/$C.tar.gz  $Path 

echo "
Peso del Tar: `du -hs ~/$C.tar.gz`
Nombre del Cliente: $C
"
rm -rf  $Path
 
