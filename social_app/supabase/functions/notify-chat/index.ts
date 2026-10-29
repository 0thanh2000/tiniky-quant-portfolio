import {handler} from '../_shared/notify.ts';
Deno.serve(handler('chat'));
