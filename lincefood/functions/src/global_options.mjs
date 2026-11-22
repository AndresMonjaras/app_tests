import { setGlobalOptions } from 'firebase-functions/v2';

// Se importa antes que cualquier función. Sin estos límites cada función
// reserva 1 vCPU y hasta 100 instancias, y el despliegue supera la cuota
// regional de CPU. Con CPU fraccionaria (como la 1.ª generación) basta para
// el volumen de la cafetería.
setGlobalOptions({ region: 'us-central1', maxInstances: 5, cpu: 'gcf_gen1' });
