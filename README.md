# Sistema de reembolso de gastos — Prueba técnica Consware

MVP de un sistema de reembolsos con tres partes que comparten una única API:

| Parte | Tecnología | Rol | Estado |
|---|---|---|---|
| **API REST** | ASP.NET Core 8 + EF Core 8 + SQL Server | Reglas de negocio y persistencia | ✅ Completa, con Swagger y tests |
| **App móvil** | Flutter 3.47 (Android) | Empleado: registra gastos y consulta sus solicitudes | ✅ Completa, con tests |
| **Panel web** | Angular 22 | Aprobador: aprueba o rechaza solicitudes pendientes | ✅ Completo, con tests |

```
Flutter (empleado) ──┐
                     ├── HTTP/JSON ──> ASP.NET Core API ──> EF Core ──> SQL Server
Angular (aprobador) ─┘                 (reglas de negocio)
```

Los clientes nunca acceden a la base de datos: la API es la única fuente de verdad.

---

## Reglas de negocio

| Regla | Dónde se aplica |
|---|---|
| Monto **≤ $500.000 COP** → se aprueba automáticamente al crearse | `ReimbursementService.CreateAsync` |
| Monto **> $500.000 COP** → queda **Pendiente** (500.000,01 ya es pendiente) | `ReimbursementService.CreateAsync` |
| Monto > 0; categoría, descripción y nombre obligatorios (no solo espacios) | Servicio + `CHECK` en SQL |
| Rechazar exige un **motivo** no vacío | Servicio + `CHECK` en SQL + validación en el panel |
| Una solicitud **Aprobada o Rechazada no cambia de estado** (409) | `ReimbursementService.FindPendingAsync` |

Las reglas viven en el backend. Los frontends validan solo para dar retroalimentación inmediata; la app móvil además anticipa si el monto se aprobará solo, pero quien decide es la API.

---

## Requisitos previos

| Herramienta | Versión usada |
|---|---|
| .NET SDK | 8.0.x |
| Herramienta EF Core | `dotnet tool install --global dotnet-ef --version 8.*` |
| SQL Server | 2022 Express (cualquier edición/instancia accesible sirve) |
| Flutter SDK | 3.47 (stable), con Android SDK 36 y un emulador |
| Node.js | 26 LTS (npm 11) |

---

## 1. Base de datos (SQL Server)

La cadena de conexión está en [`backend/Consware.Reimbursements.Api/appsettings.json`](backend/Consware.Reimbursements.Api/appsettings.json):

```json
"DefaultConnection": "Server=localhost\\SQLEXPRESS;Database=ConswareReembolsosDB;Trusted_Connection=True;TrustServerCertificate=True;"
```

- **Cambia `Server=`** por tu instancia (por ejemplo `localhost`, `.\\SQLEXPRESS` o `(localdb)\\MSSQLLocalDB`). En JSON la barra invertida va doble.
- Usa autenticación integrada de Windows: tu usuario necesita permiso para crear bases de datos. Si no lo tiene, crea una base vacía `ConswareReembolsosDB` desde SSMS con una cuenta autorizada.
- `TrustServerCertificate=True` es solo para desarrollo local.

Crear la base y la tabla con la migración incluida:

```bash
cd backend/Consware.Reimbursements.Api
dotnet ef database update
```

Esto crea `ConswareReembolsosDB` con la tabla `dbo.ReimbursementRequests` (montos `DECIMAL(18,2)`, restricciones `CHECK` e índices por `Status` y `EmployeeName`). No ejecutes scripts SQL manuales: la fuente del esquema es la migración.

Para verla en SSMS: conéctate a tu instancia con *Windows Authentication* y marca *Trust server certificate*.

---

## 2. Backend (API)

```bash
cd backend/Consware.Reimbursements.Api
dotnet restore
dotnet ef database update
dotnet run --launch-profile http        # escucha en http://0.0.0.0:5000
```

- **Swagger:** http://localhost:5000/swagger
- **Comprobación rápida:** http://localhost:5000/api/reimbursements
- **Tests:** desde `backend/`, `dotnet test` (usa EF InMemory, no necesita SQL Server).

### Endpoints

| Método | Ruta | Descripción | Respuestas |
|---|---|---|---|
| POST | `/api/reimbursements` | Crea una solicitud y aplica la regla de $500.000 | 201 (+ `Location`), 400 |
| GET | `/api/reimbursements?status=&employeeName=` | Lista, con filtros combinables | 200 (`[]` si no hay), 400 si el estado no existe |
| GET | `/api/reimbursements/{id}` | Detalle | 200, 404 |
| PATCH | `/api/reimbursements/{id}/approve` | Aprueba una pendiente | 200, 404, 409 |
| PATCH | `/api/reimbursements/{id}/reject` | Rechaza una pendiente. Body: `{"reason": "..."}` | 200, 400, 404, 409 |

Todos los errores devuelven `{"message": "..."}`. Los 500 usan un mensaje genérico, sin detalles de SQL Server.

Ejemplo:

```bash
curl -X POST http://localhost:5000/api/reimbursements \
  -H "Content-Type: application/json" \
  -d '{"employeeName":"Empleado Demo","amount":650000,"category":"Transporte","description":"Taxi a reunión"}'
```

---

## 3. App móvil (Flutter)

```bash
cd mobile
flutter pub get
flutter run            # con el emulador Android encendido
flutter test           # tests
```

- La URL de la API está en [`mobile/lib/config/api_config.dart`](mobile/lib/config/api_config.dart). Por defecto es `http://10.0.2.2:5000`, que es el PC visto desde el emulador Android.
- **Celular físico:** `flutter run --dart-define=API_BASE_URL=http://<IP-LAN-DEL-PC>:5000`. Agrega esa IP en [`network_security_config.xml`](mobile/android/app/src/main/res/xml/network_security_config.xml), que solo permite HTTP sin cifrar hacia hosts de desarrollo, y abre el puerto 5000 en el Firewall de Windows.
- **Usuarios:** no hay login. Al abrir la app eliges tu nombre de una lista (`ApiConfig.employees`), como permite el enunciado, y puedes cambiar de empleado desde la barra superior.

Pantallas:
- **¿Quién eres?:** selector de empleado.
- **Mis solicitudes:** lista con estado, motivo de rechazo y filtros por estado. Se actualiza deslizando hacia abajo y tiene estados de carga, vacío y error con *Reintentar*.
- **Registrar gasto:** monto con separador de miles, categoría y descripción, con validación en pantalla. Evita el doble envío y muestra el error de la API sin romper la pantalla.

---

## 4. Panel web (Angular)

```bash
cd web
npm install
npm start              # http://localhost:4200
npm test -- --watch=false
```

- La URL de la API se define en [`web/src/app/config/api.config.ts`](web/src/app/config/api.config.ts) (`http://localhost:5000/api/reimbursements`).
- La API permite por CORS el origen `http://localhost:4200`. Si cambias el puerto, ajusta `Cors:AllowedOrigins` en `appsettings.json`.
- La tabla abre filtrada en **Pendientes**, con filtros Aprobadas, Rechazadas y Todas. Aprobar pide confirmación; rechazar abre un diálogo con el motivo obligatorio. Ante un 409 explica que la solicitud ya fue decidida y recarga la tabla.

---

## Flujo de punta a punta

1. En Flutter, elige "Empleado Demo" y registra **$650.000** → queda **Pendiente**.
2. En Angular aparece en *Pendientes* → **Rechazar** con un motivo.
3. En Flutter, desliza para actualizar → la solicitud aparece **Rechazada** con el motivo.
4. Reinicia la API y consulta otra vez → los datos siguen en SQL Server.

---

## Pruebas realizadas

**Automáticas: 69 tests, todos pasan.**

| Proyecto | Tests | Cobertura principal |
|---|---|---|
| Backend (xUnit) | 35 | Límite 500.000 / 500.000,01 / 500.001, validaciones, filtros combinados, estados finales (409), 404, JSON inválido, cabecera `Location`, lista vacía `[]`, CORS |
| Flutter | 24 | Parseo de JSON, formato de moneda, cliente HTTP (400 / 500 / sin conexión / JSON inválido), formulario que no llama a la API si está incompleto, filtros, estado vacío, error con reintento, selector de empleado |
| Angular (Vitest) | 10 | Servicio HTTP, filtro inicial *Pendientes*, rechazo sin motivo bloqueado, rechazo con motivo, aviso de 409, API caída |

**Manuales, contra SQL Server real:**
- Matriz de la guía con `curl`: 100.000 y 500.000 → Approved; 500.001 y 500.000,01 → Pending; monto 0 o -1, descripción solo con espacios, categoría vacía y JSON malformado → 400; id inexistente → 404; aprobar o rechazar una solicitud ya decidida → 409; rechazo con motivo vacío → 400 y la solicitud sigue Pending.
- Persistencia: reiniciar la API y consultar → los datos siguen ahí.
- Flujo completo Flutter (emulador) → Angular (navegador) → Flutter, incluido un rechazo con motivo.
- Conectividad del emulador hacia `10.0.2.2:5000`.

---

## Decisiones técnicas

- **SQL Server + EF Core con migraciones:** cumple el requisito SQL, aporta `DECIMAL(18,2)` para dinero y el esquema queda versionado en el repositorio. Las restricciones `CHECK` son una segunda defensa; la validación principal está en el servicio, con mensajes claros.
- **Un solo backend con capas (Controller → Service → DbContext):** un dominio pequeño no justifica microservicios. La regla de $500.000 vive en `ReimbursementService`, así que se puede cambiar o probar sin tocar HTTP ni los clientes.
- **Una tabla, sin tabla de usuarios:** el enunciado permite identificar al empleado por nombre y no pide login. Las categorías son texto controlado por la interfaz.
- **Errores de dominio como excepciones tipadas** (`ValidationException`, `NotFoundException`, `InvalidTransitionException`), traducidas a 400/404/409 en un único `IExceptionHandler`. El controller queda delgado y el formato de error es uniforme.
- **DTOs separados de la entidad:** el estado se expone como texto (`"Pending"`) y las fechas en UTC con `Z`.
- **`TimeProvider` inyectado:** permite probar las fechas de decisión con un reloj falso.
- **Flutter con `setState` y estados *sealed*:** con dos pantallas no hace falta BLoC ni Riverpod. El acceso HTTP está aislado en `ReimbursementApiService`, que traduce cualquier fallo a un `ApiException` con mensaje para el usuario.
- **Angular con signals y Signal Forms:** el motivo de rechazo usa Signal Forms (recomendado para formularios nuevos en Angular 22). La URL de la API llega por `InjectionToken`, lo que facilita los tests.
- **Diseño:** paleta de Consware (navy `#03045E`, cian `#00BEFB`) y tipografía Poppins en ambos clientes. Los colores de estado (aprobada, pendiente, rechazada) son semánticos y se mantienen aparte.

---

## Fuera de alcance y cómo lo abordaría

| Pendiente | Cómo lo haría |
|---|---|
| Autenticación y roles (empleado / aprobador) | JWT u OpenID Connect (Entra ID); el empleado saldría del token y no de un parámetro, y las rutas de decisión exigirían el rol aprobador |
| Concurrencia entre aprobadores | Columna `rowversion` como token de concurrencia en EF Core y respuesta 409 ante conflicto |
| Adjuntar recibos | Almacenamiento de blobs (Azure Blob o S3) y una tabla de adjuntos ligada a la solicitud |
| Auditoría | Tabla de historial de cambios de estado: quién, cuándo y desde qué estado |
| Catálogo de empleados y categorías | Tablas maestras con claves foráneas en lugar de texto libre |
| Paginación del listado | `page`/`pageSize` en el GET; ahora devuelve todo |
| Tests contra SQL Server real | Testcontainers con la imagen de SQL Server; hoy los tests de integración usan EF InMemory |
| Despliegue y CI | Pipeline de GitHub Actions con build y tests de los tres proyectos; secretos fuera del repositorio |

---

## Solución de problemas

| Problema | Solución |
|---|---|
| `SqlException` / `Login failed` | Revisa `Server=` en `appsettings.json` y que tu usuario de Windows tenga acceso a la instancia |
| Flutter: `Connection refused` | La API debe estar corriendo; en el emulador usa `10.0.2.2`, no `localhost` |
| Angular: error de CORS | El origen debe ser exactamente `http://localhost:4200` |
| Gradle pide el NDK y no lo instala | `sdkmanager "ndk/28.2.13676358"` |
| Errores al borrar archivos de `build/`, `bin/` u `obj/` | Si el proyecto está dentro de OneDrive, la sincronización bloquea los archivos. Saca el proyecto de OneDrive o enlaza esas carpetas a una ruta externa |
| Instalar SQL Server en Windows en español de México | El instalador no admite `es-MX`; usa el medio en inglés con `/ENU` |

---

## Uso de IA

Usé **Claude Code** (modelo Claude Opus) como asistente de desarrollo durante toda la prueba, guiado por skills del repositorio en [`.claude/skills/`](.claude/skills/), tomadas de los repos ECC e impeccable: `dotnet-patterns`, `api-design`, `csharp-testing`, `dart-flutter-patterns`, `angular-developer`, `impeccable`, entre otras.

- **Qué hizo la IA:** preparó el entorno (SQL Server Express, Android SDK, emulador), generó el código inicial de la API, la app Flutter y el panel Angular a partir de la guía técnica, escribió los tests y el diseño con la paleta de Consware, y redactó este README.
- **Qué hice yo:** definí el alcance y el orden de trabajo, elegí las tecnologías y la instancia de base de datos, revisé cada parte antes de hacer commit, probé el flujo completo en el emulador y en el navegador, y pedí correcciones (por ejemplo, el contraste de las tarjetas en la app móvil y el selector de empleado).
- **Verificación:** cada parte se compiló y se probó contra la API y SQL Server reales. Los tests automáticos detectaron dos errores que se corrigieron: campos del formulario de Flutter que dejaban de validarse al salir de pantalla, y el botón "Cambiar de empleado", que no volvía al selector.

Puedo explicar y modificar cualquier parte del código.
