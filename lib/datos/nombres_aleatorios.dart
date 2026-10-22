// Listas de nombres, apellidos, nicks y países para generar jugadores
// jóvenes aleatorios. Puedes agregar más palabras cuando quieras.

/// Nombres de pila (mezcla de distintas regiones, incluida Latinoamérica).
const List<String> nombres = [
  'Santiago',
  'Mateo',
  'Sebastián',
  'Diego',
  'Joaquín',
  'Benjamín',
  'Martín',
  'Alejandro',
  'Tomás',
  'Facundo',
  'Nicolás',
  'Lucas',
  'Gabriel',
  'Daniel',
  'Andrés',
  'Javier',
  'Miguel',
  'Pedro',
  'Juan',
  'Felipe',
  'Ignacio',
  'Emiliano',
  'Thiago',
  'Rafael',
  'Bruno',
  'Kevin',
  'Ethan',
  'Noah',
  'Liam',
  'Oliver',
  'Min-jun',
  'Seo-jun',
  'Ji-ho',
  'Hyun',
  'Yun',
  'Jun',
  'Wei',
  'Hao',
  'Ming',
  'Chen',
  'Kai',
  'Ling',
  'Oskar',
  'Elias',
  'Nikolai',
  'Ivan',
  'Dmitri',
  'Pavel',
];

/// Apellidos.
const List<String> apellidos = [
  'González',
  'Muñoz',
  'Rojas',
  'Pérez',
  'Soto',
  'Contreras',
  'Silva',
  'Martínez',
  'López',
  'García',
  'Rodríguez',
  'Fernández',
  'Hernández',
  'Díaz',
  'Torres',
  'Flores',
  'Ramírez',
  'Vásquez',
  'Castillo',
  'Reyes',
  'Morales',
  'Ortiz',
  'Gutiérrez',
  'Castro',
  'Kim',
  'Lee',
  'Park',
  'Choi',
  'Wang',
  'Zhang',
  'Novak',
  'Petrov',
  'Sokolov',
  'Müller',
  'Andersen',
  'Kowalski',
];

/// Primera parte de un nick (palabra inventada o común).
const List<String> nicksBase = [
  'Shadow',
  'Kira',
  'Vex',
  'Nova',
  'Zeus',
  'Apex',
  'Blaze',
  'Frost',
  'Storm',
  'Raven',
  'Pixel',
  'Ghost',
  'Turbo',
  'Lynx',
  'Onyx',
  'Viper',
  'Cobra',
  'Drift',
  'Echo',
  'Fury',
  'Glitch',
  'Hawk',
  'Jinx',
  'Kraken',
  'Lunar',
  'Mystic',
  'Ninja',
  'Omega',
  'Phoenix',
  'Quake',
  'Riot',
  'Saber',
  'Titan',
  'Umbra',
  'Venom',
  'Wolf',
  'Xeno',
  'Yuki',
  'Zed',
  'Rogue',
  'Sniper',
  'Dash',
  'Fenix',
  'Neon',
  'Pulse',
  'Blitz',
  'Cero',
  'Dante',
];

/// Segunda parte opcional del nick (sufijos).
const List<String> nicksSufijo = [
  'x',
  'z',
  'GG',
  'TV',
  'Pro',
  'God',
  'King',
  'Zero',
  'One',
  'X',
  'Esports',
  'Plays',
  'OP',
];

/// Países posibles para los jugadores generados (incluye Latinoamérica).
const List<String> paises = [
  'Chile',
  'Argentina',
  'Brasil',
  'México',
  'Perú',
  'Colombia',
  'Uruguay',
  'España',
  'Estados Unidos',
  'Canadá',
  'Corea del Sur',
  'China',
  'Japón',
  'Suecia',
  'Dinamarca',
  'Polonia',
  'Francia',
  'Alemania',
  'Reino Unido',
  'Rusia',
  'Ucrania',
  'Australia',
];

/// Países que se ofrecen al crear el agente (el usuario elige uno).
const List<String> paisesAgente = [
  'Chile',
  'Argentina',
  'México',
  'Perú',
  'Colombia',
  'Uruguay',
  'España',
  'Brasil',
  'Estados Unidos',
  'Corea del Sur',
  'China',
  'Japón',
  'Suecia',
  'Dinamarca',
  'Francia',
  'Alemania',
];

/// Perfil de nombres de una región: nombres, apellidos y países típicos.
/// Se usa para que los jugadores generados encajen con la región del equipo.
class PerfilNombres {
  const PerfilNombres(this.nombres, this.apellidos, this.paises);

  final List<String> nombres;
  final List<String> apellidos;
  final List<String> paises;
}

const PerfilNombres _perfilGeneral = PerfilNombres(nombres, apellidos, paises);

const PerfilNombres _perfilCorea = PerfilNombres(
  [
    'Min-jun',
    'Seo-jun',
    'Ji-ho',
    'Hyun',
    'Yun',
    'Jun',
    'Han',
    'Do-yun',
    'Ji-hoon',
    'Woo-jin',
  ],
  ['Kim', 'Lee', 'Park', 'Choi', 'Jung', 'Kang', 'Cho', 'Yoon', 'Jang', 'Lim'],
  ['Corea del Sur'],
);

const PerfilNombres _perfilChina = PerfilNombres(
  ['Wei', 'Hao', 'Ming', 'Chen', 'Kai', 'Ling', 'Jian', 'Bo', 'Tao', 'Feng'],
  ['Wang', 'Zhang', 'Li', 'Liu', 'Chen', 'Yang', 'Zhao', 'Huang', 'Zhou', 'Wu'],
  ['China'],
);

const PerfilNombres _perfilEuropa = PerfilNombres(
  [
    'Oskar',
    'Elias',
    'Nikolai',
    'Ivan',
    'Lukas',
    'Matteo',
    'Hugo',
    'Lars',
    'Milan',
    'Andrei',
  ],
  [
    'Novak',
    'Petrov',
    'Sokolov',
    'Müller',
    'Andersen',
    'Kowalski',
    'Rossi',
    'Dubois',
    'Johansson',
    'Jensen',
  ],
  [
    'Suecia',
    'Dinamarca',
    'Polonia',
    'Francia',
    'Alemania',
    'Reino Unido',
    'España',
    'Italia',
  ],
);

const PerfilNombres _perfilEuropaEste = PerfilNombres(
  [
    'Ivan',
    'Dmitri',
    'Pavel',
    'Nikolai',
    'Alexei',
    'Marek',
    'Tomas',
    'Andrei',
    'Viktor',
    'Sergei',
  ],
  [
    'Petrov',
    'Sokolov',
    'Ivanov',
    'Volkov',
    'Kuznetsov',
    'Novak',
    'Kowalski',
    'Horvath',
    'Popa',
    'Ionescu',
  ],
  [
    'Rusia',
    'Ucrania',
    'Polonia',
    'República Checa',
    'Hungría',
    'Rumanía',
    'Letonia',
    'Lituania',
    'Estonia',
  ],
);

const PerfilNombres _perfilNorteamerica = PerfilNombres(
  [
    'Ethan',
    'Noah',
    'Liam',
    'Oliver',
    'Mason',
    'Logan',
    'Tyler',
    'Ryan',
    'Jacob',
    'Cole',
  ],
  [
    'Smith',
    'Johnson',
    'Williams',
    'Brown',
    'Jones',
    'Miller',
    'Davis',
    'Wilson',
    'Taylor',
    'Anderson',
  ],
  ['Estados Unidos', 'Canadá'],
);

const PerfilNombres _perfilBrasil = PerfilNombres(
  [
    'Rafael',
    'Bruno',
    'Thiago',
    'Gabriel',
    'Lucas',
    'Mateus',
    'Felipe',
    'Vitor',
    'Caio',
    'Pedro',
  ],
  [
    'Silva',
    'Santos',
    'Oliveira',
    'Souza',
    'Pereira',
    'Lima',
    'Costa',
    'Ferreira',
    'Almeida',
    'Rocha',
  ],
  ['Brasil'],
);

const PerfilNombres _perfilLatam = PerfilNombres(
  [
    'Santiago',
    'Mateo',
    'Sebastián',
    'Diego',
    'Joaquín',
    'Benjamín',
    'Martín',
    'Alejandro',
    'Tomás',
    'Facundo',
  ],
  [
    'González',
    'Muñoz',
    'Rojas',
    'Pérez',
    'Soto',
    'Contreras',
    'Martínez',
    'López',
    'García',
    'Rodríguez',
  ],
  ['Chile', 'Argentina', 'México', 'Perú', 'Colombia', 'Uruguay'],
);

const PerfilNombres _perfilAsiaPacifico = PerfilNombres(
  [
    'Haruto',
    'Sota',
    'Yuto',
    'Kenji',
    'Riku',
    'Min-ho',
    'Jun',
    'Arif',
    'Budi',
    'Nguyen',
  ],
  [
    'Sato',
    'Suzuki',
    'Takahashi',
    'Tanaka',
    'Watanabe',
    'Kim',
    'Nguyen',
    'Tran',
    'Putra',
    'Santos',
  ],
  [
    'Japón',
    'Corea del Sur',
    'Indonesia',
    'Malasia',
    'Filipinas',
    'Australia',
    'Singapur',
    'Vietnam',
  ],
);

const PerfilNombres _perfilMedioOriente = PerfilNombres(
  [
    'Ahmed',
    'Yusuf',
    'Omar',
    'Khalid',
    'Faisal',
    'Ali',
    'Hassan',
    'Tariq',
    'Bilal',
    'Sami',
  ],
  [
    'Al-Farsi',
    'Haddad',
    'Nasser',
    'Saleh',
    'Mansour',
    'Khalil',
    'Aziz',
    'Rashid',
    'Karim',
    'Farouk',
  ],
  ['Turquía', 'Arabia Saudita', 'Emiratos Árabes Unidos', 'Egipto', 'Jordania'],
);

/// Devuelve el perfil de nombres que corresponde a una región.
/// Si la región no se reconoce, usa el perfil general.
PerfilNombres perfilDeRegion(String region) {
  switch (region) {
    case 'Corea':
      return _perfilCorea;
    case 'China':
      return _perfilChina;
    case 'Europa':
    case 'Europa Occidental':
    case 'EMEA':
      return _perfilEuropa;
    case 'Europa del Este':
      return _perfilEuropaEste;
    case 'Norteamérica':
      return _perfilNorteamerica;
    case 'Brasil':
      return _perfilBrasil;
    case 'Latinoamérica':
    case 'Latinoamérica Sur':
    case 'Sudamérica':
      return _perfilLatam;
    case 'Pacífico':
    case 'Sudeste Asiático':
    case 'Asia-Oceanía':
    case 'Américas':
      return _perfilAsiaPacifico;
    case 'Medio Oriente':
      return _perfilMedioOriente;
    default:
      return _perfilGeneral;
  }
}
