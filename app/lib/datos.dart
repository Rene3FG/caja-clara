import 'modelos.dart';

const marcaTienda = 'MIS ABARROTES';
const nombreTienda = 'Abarrotes Doña Elena';
const duena = 'Doña Elena';

const titular = 'Elena Morales';
const banco = 'Cuenta Básica / SPEI';
const clabe = '646180112000458912';
const clabeVisible = '6461 8011 2000 4589 12';
const notaSeguridad = 'Solo comparte estos datos para recibir pagos; nunca des contraseñas ni códigos.';

const bienvenidaSaludo = '¡Hola! Soy Cempasúchil';
const bienvenidaTexto =
    'Te acompaño paso a paso a cuidar tu negocio y tus cuentas con total tranquilidad. Aquí aprenderemos juntos cosas como cómo abrir una cuenta de banco, hacer transferencias y cobrar con QR, sin prisas ni palabras difíciles.';

const pasos = <PasoGuia>[
  PasoGuia(
    id: TemaGuia.cuenta,
    titulo: 'Cuenta de banco básica',
    etiqueta: 'Subpaso 1 de 3',
    mensaje:
        'Una cuenta básica de débito te sirve para guardar el dinero de tus ventas con total seguridad. Nadie te cobra comisiones ni cuotas por tenerla. Solo necesitas tu credencial (INE) y tu celular para abrirla.',
    detalleTitulo: 'Cómo funciona tu cuenta básica',
    detalle:
        'Una cuenta básica es un lugar seguro para guardar el dinero de tus ventas diarias sin miedo a perderlo. Por ley en México, está protegida y no te cobran comisiones por mantenerla abierta ni te exigen un saldo mínimo guardado.',
    nota: 'Identificarte es muy fácil con tu CURP Digital o tu credencial de elector desde el teléfono, sin trámites complicados.',
    pasos: [
      'Tener a la mano tu credencial (INE o CURP Digital) y tu número de celular activo.',
      'Elegir una cuenta básica de débito sin comisiones por saldo mínimo ni apertura.',
      'Definir tu clave secreta (NIP) o huella digital para proteger tu acceso.',
    ],
    tituloAcude: '¿Necesita acudir a una sucursal?',
    acude: 'No necesariamente: muchas cuentas básicas se abren directamente desde el celular; acudir a una sucursal es totalmente opcional.',
    proteccion: 'Protegido por las normas oficiales para cuentas básicas.',
    pregunta: '¿Me van a cobrar por tener poco dinero guardado?',
    respuesta:
        '¡No te preocupes! Las cuentas de banco básicas están protegidas por ley en México. No te cobran comisiones por tener poco saldo ni te exigen una cantidad mínima de dinero guardado. Tu dinero está seguro y completo, peso por peso.',
  ),
  PasoGuia(
    id: TemaGuia.transferencia,
    titulo: 'Datos para una transferencia',
    etiqueta: 'Subpaso 2 de 3',
    mensaje:
        'Para que un cliente te pague por transferencia bancaria (como SPEI sin ningún costo), solo necesitas compartirle datos de recepción: tu cuenta CLABE de 18 números o tu número de celular registrado. Jamás debes compartir tus contraseñas, NIP ni códigos que te lleguen por mensaje.',
    chip: 'Cero comisiones · 100% seguro',
    conDescarga: true,
    detalleTitulo: 'Qué datos compartir y cuáles NO',
    detalle:
        'Para recibir tu dinero de forma segura, solo compartes tus datos de recepción: tu CLABE de 18 números, tu número de tarjeta o tu celular vinculado a tu cuenta. Nunca compartas tu NIP, tus contraseñas del banco ni códigos que te lleguen por SMS: esos son secretos y solo tuyos.',
    comparteSi: 'CLABE o número de celular',
    comparteNo: 'NIP ni contraseñas del banco',
    lead: '¡No, para nada!',
    cajaRosa: 'Solo recuerda: nunca compartas tu NIP ni los códigos que recibas por mensaje.',
    cajaVerde: 'Tu cuenta está blindada. Los datos de recepción solo sirven para recibir pagos.',
    pasos: [
      'Localizar tu CLABE de 18 números o vincular tu celular en la app de tu banco.',
      'Anotarla o tenerla a la mano para dictársela o mostrársela a tus clientes cuando compren.',
      'Revisar en tu propia app del banco que el dinero haya entrado antes de entregar la mercancía.',
    ],
    acude: 'No: puedes consultar tu CLABE o vincular tu número de teléfono directamente desde la aplicación de tu banco o en tu contrato, sin filas ni sucursales.',
    pregunta: '¿Es peligroso darle mi número de celular o CLABE a quien me va a pagar?',
    respuesta:
        'Compartir tu CLABE de 18 números o tu celular vinculado es totalmente seguro. Con esos datos la persona únicamente puede depositarte dinero a tu favor, jamás podrá sacarte dinero ni entrar a tu cuenta.',
  ),
  PasoGuia(
    id: TemaGuia.sat,
    titulo: 'Formalizarse con el SAT',
    etiqueta: 'Subpaso 3 de 3',
    mensaje:
        'Darse de alta en el SAT y tener tu RFC pone en orden las cuentas de tu negocio. Sirve para anotar lo que vendes y lo que gastas con tranquilidad, y para poder pedir un apoyo o venderle a más personas cuando tú lo decidas.',
    detalleTitulo: 'Cómo funciona registrarte en el SAT',
    detalle:
        'Obtienes tu RFC y eliges un régimen sencillo, pensado para un negocio pequeño. Llevar la cuenta de lo que entra y lo que sale te deja el negocio en orden, con calma y sin palabras difíciles.',
    pasos: [
      'Reúne tu identificación (INE o CURP) y un comprobante de domicilio reciente.',
      'Lleva un registro sencillo, en libreta o en esta app, de tus ventas y tus compras.',
      'Cuando estés lista, pide cita en el portal del SAT para tu RFC y tu firma.',
    ],
    acude:
        'Sí. Para el alta por primera vez, o para la firma, se pide cita y se acude a un módulo del SAT. No hace falta ir para anotar las ventas de hoy.',
    pregunta: '¿A partir de cuándo me conviene darme de alta en el SAT y qué pasa si apenas empiezo?',
    respuesta:
        'Si apenas empiezas, puedes ordenar tus cuentas con calma. Conviene darte de alta cuando quieras notas formales, un crédito para el negocio o un apoyo. Hay un régimen sencillo para comercios pequeños.',
  ),
];

List<Producto> productosBase() => [
      Producto(id: 'p1', nombre: 'Quesadillas', detalle: 'Comal al comal tradicional', precio: 35),
      Producto(id: 'p2', nombre: 'Café de olla', detalle: 'Con canela y piloncillo', precio: 25),
      Producto(id: 'p3', nombre: 'Aguas frescas', detalle: 'Fruta fresca del día', precio: 20),
      Producto(id: 'p4', nombre: 'Pan dulce', detalle: 'Hornada de la mañana', precio: 15),
    ];

DateTime marca(int dias, int hora, int minuto) {
  final hoy = DateTime.now();
  final dia = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: dias));
  return DateTime(dia.year, dia.month, dia.day, hora, minuto);
}

List<Venta> ventasBase() => [
      Venta(
        id: 'v1',
        en: marca(0, 11, 40),
        metodo: Metodo.efectivo,
        total: 58,
        pendiente: false,
        lineas: [
          Linea(productoId: '', nombre: 'Refresco', precio: 18, cantidad: 2),
          Linea(productoId: '', nombre: 'Sabritas', precio: 22, cantidad: 1),
        ],
      ),
      Venta(
        id: 'v2',
        en: marca(0, 10, 55),
        metodo: Metodo.qr,
        total: 135,
        pendiente: false,
        lineas: [
          Linea(productoId: '', nombre: 'Aceite 1L', precio: 48, cantidad: 1),
          Linea(productoId: '', nombre: 'Frijol', precio: 42, cantidad: 1),
          Linea(productoId: '', nombre: 'Arroz', precio: 45, cantidad: 1),
        ],
      ),
      Venta(
        id: 'v3',
        en: marca(0, 10, 15),
        metodo: Metodo.qr,
        total: 95,
        pendiente: false,
        lineas: [
          Linea(productoId: 'p1', nombre: 'Quesadillas', precio: 35, cantidad: 2),
          Linea(productoId: 'p2', nombre: 'Café de olla', precio: 25, cantidad: 1),
        ],
      ),
      Venta(
        id: 'v4',
        en: marca(0, 9, 20),
        metodo: Metodo.efectivo,
        total: 112,
        pendiente: false,
        lineas: [
          Linea(productoId: 'p3', nombre: 'Aguas frescas', precio: 20, cantidad: 4),
          Linea(productoId: 'p4', nombre: 'Pan dulce', precio: 16, cantidad: 2),
        ],
      ),
      Venta(
        id: 'v5',
        en: marca(0, 8, 10),
        metodo: Metodo.transferencia,
        total: 230,
        pendiente: false,
        lineas: [Linea(productoId: '', nombre: 'Abarrotes surtidos y veladora', precio: 230, cantidad: 1)],
      ),
      Venta(
        id: 'v6',
        en: marca(2, 13, 0),
        metodo: Metodo.efectivo,
        total: 200,
        pendiente: false,
        lineas: [Linea(productoId: '', nombre: 'Mandado de la semana', precio: 200, cantidad: 1)],
      ),
      Venta(
        id: 'v7',
        en: marca(10, 11, 0),
        metodo: Metodo.efectivo,
        total: 50,
        pendiente: false,
        lineas: [Linea(productoId: 'p2', nombre: 'Café de olla', precio: 25, cantidad: 2)],
      ),
    ];

List<Gasto> gastosBase() => [
      Gasto(id: 'g1', en: marca(0, 7, 30), concepto: 'Pan dulce y bolillos', monto: 100, metodo: Metodo.transferencia, pendiente: false),
      Gasto(id: 'g2', en: marca(0, 7, 50), concepto: 'Hielo en bolsa y bolsas', monto: 50, metodo: Metodo.efectivo, pendiente: false),
      Gasto(id: 'g3', en: marca(2, 9, 0), concepto: 'Refrescos para el mostrador', monto: 40, metodo: Metodo.efectivo, pendiente: false),
      Gasto(id: 'g4', en: marca(10, 8, 0), concepto: 'Azúcar', monto: 10, metodo: Metodo.efectivo, pendiente: false),
    ];

List<Fiado> fiadosBase() => [
      Fiado(id: 'f1', nombre: 'Don Ramón', nota: 'Refrescos de la semana', monto: 80, pagado: false),
      Fiado(id: 'f2', nombre: 'Doña Lupita', nota: 'Pan de ayer', monto: 45, pagado: false),
    ];
