CREATE OR REPLACE FUNCTION tes.f_inserta_solicitud_efectivo (
  p_administrador integer,
  p_id_usuario integer,
  p_hstore public.hstore
)
RETURNS varchar AS
$body$
/**************************************************************************
 SISTEMA:		Obligaciones de Pago
 FUNCION: 		tes.f_inserta_solicitud_efectivo
 DESCRIPCION:   Inserta registro de solicitud efectivo
 AUTOR: 		Gonzalo Sarmiento 
 FECHA:	        10-02-2015
 COMENTARIOS:	
***************************************************************************
 HISTORIAL DE MODIFICACIONES:

 DESCRIPCION:	
 AUTOR:			
 FECHA:		
***************************************************************************/

DECLARE
	
	v_id_solicitud_efectivo	integer;
    v_codigo_tabla			varchar;
    v_num_sol_efe			varchar;
    v_id_gestion			integer;
    v_codigo_tipo_proceso	varchar;
    v_num_tramite			varchar;
    v_id_proceso_wf			integer;
    v_id_estado_wf			integer;
    v_codigo_estado			varchar;
    v_motivo				varchar;
    v_tipo					varchar;
    v_id_tipo_solicitud		integer;
    v_fk_id_solicitud_efectivo	integer;
    v_nombre_funcion		varchar;
    v_resp					varchar;
    v_codigo_proceso_llave_wf	varchar;

BEGIN
            v_nombre_funcion = 'f_inserta_solicitud_efectivo';

            /*
            HSTORE  PARAMETERS
                    (p_hstore->'id_caja')::integer
                    (p_hstore->'monto')::numeric
                    (p_hstore->'id_funcionario')::integer
                    (p_hstore->'tipo')::varchar,
                    (p_hstore->'fecha')::date,
					(p_hstore->'motivo')::varchar,
                    (p_hstore->'id_solicitud_efectivo')::integer                                
            */

			select pv.codigo into v_codigo_tabla
         	from tes.tcaja pv
         	where pv.id_caja = (p_hstore->'id_caja')::integer;
            
        	IF (p_hstore->'tipo_solicitud')::varchar = 'rendicion' THEN
            	v_tipo = 'RENEFE';
            ELSIF (p_hstore->'tipo_solicitud')::varchar = 'devolucion' THEN
            	v_tipo = 'DEVEFE';
            ELSIF (p_hstore->'tipo_solicitud')::varchar = 'reposicion' THEN
                v_tipo = 'REPEFE';
            ELSIF (p_hstore->'tipo_solicitud')::varchar = 'solicitud' THEN
				v_tipo='SOLEFE';
            ELSE
            	raise exception 'Tipo de solicitud '' % '', no definido', (p_hstore->'tipo_solicitud')::varchar;
			END IF;            
            
            IF v_tipo = 'SOLEFE' THEN
              -- obtener correlativo
              v_num_sol_efe =  param.f_obtener_correlativo(
                     v_tipo, 
                     NULL,-- par_id, 
                     NULL, --id_uo 
                     NULL,    -- id_depto
                     p_id_usuario, 
                     'TES', 
                     NULL,
                     0,
                     0,
                     'tes.tcaja',
                     (p_hstore->'id_caja')::integer,
                     v_codigo_tabla                   
                     );
                --fin obtener correlativo
              IF (v_num_sol_efe is NULL or v_num_sol_efe ='') THEN
                 raise exception 'No se pudo obtener un numero correlativo para la solicitud efectivo caja consulte con el administrador';
              END IF;
            ELSE

              select nro_tramite into v_num_sol_efe
              from tes.tsolicitud_efectivo
              where id_solicitud_efectivo = (p_hstore->'id_solicitud_efectivo')::integer;

            END IF;
              
              select tp.codigo, t.id_tipo_solicitud into v_codigo_tipo_proceso, v_id_tipo_solicitud
            from tes.ttipo_solicitud t
            inner join wf.ttipo_proceso tp on tp.codigo_llave=t.codigo_proceso_llave_wf
            where t.codigo=v_tipo;

            select 
             ges.id_gestion
            into 
              v_id_gestion
            from param.tgestion ges
            where ges.gestion = (date_part('year', current_date))::integer
            limit 1 offset 0;
             
            -- inciar el tramite en el sistema de WF
             SELECT 
                   ps_num_tramite ,
                   ps_id_proceso_wf ,
                   ps_id_estado_wf ,
                   ps_codigo_estado 
                into
                   v_num_tramite,
                   v_id_proceso_wf,
                   v_id_estado_wf,
                   v_codigo_estado   
                      
              FROM wf.f_inicia_tramite(
                   p_id_usuario,
                   NULL,
                   NULL,
                   v_id_gestion, 
                   v_codigo_tipo_proceso, 
                   NULL,
                   --v_parametros.id_depto,
                   NULL,
                   'Fondo Rotativo ('||v_num_sol_efe||') '::varchar,
                   v_num_sol_efe );

            IF (p_hstore->'motivo') IS NOT NULL THEN
            	v_motivo = (p_hstore->'motivo')::varchar;
            ELSE
            	v_motivo = NULL;
            END IF;

            IF (p_hstore->'id_solicitud_efectivo') IS NOT NULL THEN
            	v_fk_id_solicitud_efectivo = (p_hstore->'id_solicitud_efectivo')::integer;
            ELSE	
            	v_fk_id_solicitud_efectivo = NULL;
            END IF;
            
            --Sentencia de la insercion
            insert into tes.tsolicitud_efectivo(
            id_caja,
            id_estado_wf,
            monto,
            id_proceso_wf,
            nro_tramite,
            estado,
            estado_reg,
            motivo,
            id_funcionario,
            fecha,
            id_usuario_ai,
            fecha_reg,
            usuario_ai,
            id_usuario_reg,
            id_usuario_mod,
            fecha_mod,
            id_tipo_solicitud,
            fk_id_solicitud_efectivo,
            id_gestion
            ) values(
            (p_hstore->'id_caja')::integer,
            v_id_estado_wf,
            (p_hstore->'monto')::numeric,
            v_id_proceso_wf,
            v_num_sol_efe,
            v_codigo_estado,
            'activo',
            v_motivo,
            (p_hstore->'id_funcionario')::integer,
            (p_hstore->'fecha')::date,
            (p_hstore->'_id_usuario_ai')::integer,
            now(),
            (p_hstore->'_nombre_usuario_ai')::varchar,
            p_id_usuario,
            null,
            null,
            v_id_tipo_solicitud,
            v_fk_id_solicitud_efectivo,
            v_id_gestion			
            )RETURNING id_solicitud_efectivo into v_id_solicitud_efectivo;

             v_resp = v_id_solicitud_efectivo::varchar;

            --Devuelve la respuesta
            return v_resp;
			
EXCEPTION
				
	WHEN OTHERS THEN
		v_resp='';
		v_resp = pxp.f_agrega_clave(v_resp,'mensaje',SQLERRM);
		v_resp = pxp.f_agrega_clave(v_resp,'codigo_error',SQLSTATE);
		v_resp = pxp.f_agrega_clave(v_resp,'procedimientos',v_nombre_funcion);
		raise exception '%',v_resp;
				        
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;