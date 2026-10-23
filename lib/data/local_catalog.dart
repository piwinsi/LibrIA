import '../core/utils.dart';
import '../models/catalog_book.dart';

/// Catálogo local de referencia. Garantiza que el onboarding y las
/// recomendaciones funcionen aun sin conexión; cuando hay internet se
/// complementa con resultados de Google Books / Open Library.
const List<CatalogBook> localCatalog = [
  // Fantasía
  CatalogBook(id: 'local_001', title: 'El nombre del viento', author: 'Patrick Rothfuss', pageCount: 872, genres: ['fantasia'], description: 'Kvothe, ya convertido en leyenda, relata su propia historia: su infancia en una troupe, su paso por la Universidad y la búsqueda de quienes asesinaron a su familia.'),
  CatalogBook(id: 'local_002', title: 'La comunidad del anillo', author: 'J. R. R. Tolkien', pageCount: 576, genres: ['fantasia', 'clasicos'], description: 'Frodo hereda un anillo de poder y emprende con sus compañeros un viaje para destruirlo antes de que caiga en manos de Sauron.'),
  CatalogBook(id: 'local_003', title: 'El hobbit', author: 'J. R. R. Tolkien', pageCount: 320, genres: ['fantasia', 'juvenil', 'clasicos'], description: 'Bilbo Bolsón deja la comodidad de su hogar para acompañar a un grupo de enanos que quiere recuperar su tesoro custodiado por un dragón.'),
  CatalogBook(id: 'local_004', title: 'Harry Potter y la piedra filosofal', author: 'J. K. Rowling', pageCount: 264, genres: ['fantasia', 'juvenil'], description: 'Un niño descubre que es mago e ingresa al colegio Hogwarts, donde encuentra amistad, misterios y un enemigo que lo marcó desde su nacimiento.'),
  CatalogBook(id: 'local_005', title: 'Juego de tronos', author: 'George R. R. Martin', pageCount: 800, genres: ['fantasia'], description: 'Las grandes casas de Poniente se disputan el Trono de Hierro mientras una amenaza antigua despierta más allá del Muro.'),
  CatalogBook(id: 'local_006', title: 'El imperio final', author: 'Brandon Sanderson', pageCount: 672, genres: ['fantasia'], description: 'En un mundo cubierto de ceniza, una joven ladrona descubre poderes alománticos y se suma a un plan para derrocar al Lord Legislador.'),
  CatalogBook(id: 'local_007', title: 'La historia interminable', author: 'Michael Ende', pageCount: 496, genres: ['fantasia', 'juvenil', 'clasicos'], description: 'Bastián lee un libro sobre el reino de Fantasía y descubre que la historia lo necesita para salvarse.'),
  CatalogBook(id: 'local_008', title: 'Circe', author: 'Madeline Miller', pageCount: 400, genres: ['fantasia', 'novela'], description: 'La hechicera de la mitología griega narra su exilio, su poder y sus encuentros con dioses y héroes.'),
  // Ciencia ficción
  CatalogBook(id: 'local_010', title: 'Dune', author: 'Frank Herbert', pageCount: 704, genres: ['ciencia_ficcion', 'clasicos'], description: 'En el planeta desértico Arrakis, Paul Atreides se ve envuelto en una lucha por el control de la especia más valiosa del universo.'),
  CatalogBook(id: 'local_011', title: 'Fundación', author: 'Isaac Asimov', pageCount: 320, genres: ['ciencia_ficcion', 'clasicos'], description: 'Un matemático predice la caída del Imperio Galáctico y crea una fundación para acortar la era de oscuridad que vendrá.'),
  CatalogBook(id: 'local_012', title: '1984', author: 'George Orwell', pageCount: 352, genres: ['ciencia_ficcion', 'clasicos'], description: 'Winston Smith vive bajo la vigilancia permanente del Gran Hermano y se atreve a cuestionar al Partido.'),
  CatalogBook(id: 'local_013', title: 'Un mundo feliz', author: 'Aldous Huxley', pageCount: 256, genres: ['ciencia_ficcion', 'clasicos'], description: 'Una sociedad futura garantiza la felicidad mediante el control biológico y el consumo, a costa de la libertad individual.'),
  CatalogBook(id: 'local_014', title: 'Fahrenheit 451', author: 'Ray Bradbury', pageCount: 192, genres: ['ciencia_ficcion', 'clasicos'], description: 'Un bombero encargado de quemar libros empieza a preguntarse qué contienen y por qué se les teme.'),
  CatalogBook(id: 'local_015', title: 'El problema de los tres cuerpos', author: 'Liu Cixin', pageCount: 416, genres: ['ciencia_ficcion'], description: 'Un proyecto secreto de la Revolución Cultural china establece contacto con una civilización extraterrestre.'),
  CatalogBook(id: 'local_016', title: 'Proyecto Hail Mary', author: 'Andy Weir', pageCount: 496, genres: ['ciencia_ficcion'], description: 'Un profesor despierta solo en una nave espacial sin recordar cómo llegó, con la misión de salvar a la humanidad.'),
  CatalogBook(id: 'local_017', title: 'El marciano', author: 'Andy Weir', pageCount: 400, genres: ['ciencia_ficcion'], description: 'Un astronauta queda abandonado en Marte y debe sobrevivir con ingenio, ciencia y mucho humor.'),
  CatalogBook(id: 'local_018', title: 'Neuromante', author: 'William Gibson', pageCount: 320, genres: ['ciencia_ficcion', 'tecnologia'], description: 'Un hacker caído en desgracia recibe una última oportunidad en un mundo dominado por corporaciones y ciberespacio.'),
  CatalogBook(id: 'local_019', title: 'La mano izquierda de la oscuridad', author: 'Ursula K. Le Guin', pageCount: 304, genres: ['ciencia_ficcion'], description: 'Un enviado llega a un planeta helado cuyos habitantes no tienen un género fijo, y debe ganarse su confianza.'),
  // Misterio y thriller
  CatalogBook(id: 'local_020', title: 'La sombra del viento', author: 'Carlos Ruiz Zafón', pageCount: 576, genres: ['misterio', 'novela'], description: 'En la Barcelona de posguerra, un joven investiga el destino de un autor cuyos libros alguien quema sistemáticamente.'),
  CatalogBook(id: 'local_021', title: 'El código Da Vinci', author: 'Dan Brown', pageCount: 560, genres: ['thriller', 'misterio'], description: 'Un simbólogo y una criptógrafa siguen pistas ocultas en obras de arte para resolver un asesinato en el Louvre.'),
  CatalogBook(id: 'local_022', title: 'Los hombres que no amaban a las mujeres', author: 'Stieg Larsson', pageCount: 672, genres: ['thriller', 'misterio'], description: 'Un periodista y una hacker investigan la desaparición de una joven ocurrida cuarenta años atrás.'),
  CatalogBook(id: 'local_023', title: 'Asesinato en el Orient Express', author: 'Agatha Christie', pageCount: 256, genres: ['misterio', 'clasicos'], description: 'Hércules Poirot debe resolver un crimen cometido en un tren detenido por la nieve.'),
  CatalogBook(id: 'local_024', title: 'Y no quedó ninguno', author: 'Agatha Christie', pageCount: 272, genres: ['misterio', 'clasicos'], description: 'Diez desconocidos son invitados a una isla y comienzan a morir uno a uno.'),
  CatalogBook(id: 'local_025', title: 'La chica del tren', author: 'Paula Hawkins', pageCount: 496, genres: ['thriller', 'misterio'], description: 'Desde la ventana del tren, Rachel observa a una pareja perfecta hasta que presencia algo que lo cambia todo.'),
  CatalogBook(id: 'local_026', title: 'El silencio de los corderos', author: 'Thomas Harris', pageCount: 368, genres: ['thriller', 'terror'], description: 'Una agente del FBI pide ayuda a un brillante psiquiatra encarcelado para atrapar a un asesino en serie.'),
  CatalogBook(id: 'local_027', title: 'Perdida', author: 'Gillian Flynn', pageCount: 560, genres: ['thriller', 'misterio'], description: 'El día de su aniversario, Amy desaparece y todas las sospechas recaen sobre su marido.'),
  CatalogBook(id: 'local_028', title: 'El nombre de la rosa', author: 'Umberto Eco', pageCount: 640, genres: ['misterio', 'historica'], description: 'Un fraile franciscano investiga una serie de muertes en una abadía medieval.'),
  // Terror
  CatalogBook(id: 'local_030', title: 'It', author: 'Stephen King', pageCount: 1504, genres: ['terror'], description: 'Un grupo de amigos se enfrenta a una entidad que adopta la forma de sus peores miedos en el pueblo de Derry.'),
  CatalogBook(id: 'local_031', title: 'El resplandor', author: 'Stephen King', pageCount: 688, genres: ['terror'], description: 'Una familia cuida un hotel aislado durante el invierno, mientras el lugar despierta algo oscuro en el padre.'),
  CatalogBook(id: 'local_032', title: 'Drácula', author: 'Bram Stoker', pageCount: 512, genres: ['terror', 'clasicos'], description: 'La novela epistolar que convirtió al conde de Transilvania en el vampiro más famoso de la literatura.'),
  CatalogBook(id: 'local_033', title: 'Frankenstein', author: 'Mary Shelley', pageCount: 288, genres: ['terror', 'clasicos', 'ciencia_ficcion'], description: 'Un científico da vida a una criatura y debe enfrentar las consecuencias de su creación.'),
  // Romance
  CatalogBook(id: 'local_040', title: 'Orgullo y prejuicio', author: 'Jane Austen', pageCount: 432, genres: ['romance', 'clasicos'], description: 'Elizabeth Bennet y el señor Darcy superan sus prejuicios en la Inglaterra rural del siglo XIX.'),
  CatalogBook(id: 'local_041', title: 'Bajo la misma estrella', author: 'John Green', pageCount: 304, genres: ['romance', 'juvenil'], description: 'Dos adolescentes que se conocen en un grupo de apoyo viven una historia de amor intensa y honesta.'),
  CatalogBook(id: 'local_042', title: 'Yo antes de ti', author: 'Jojo Moyes', pageCount: 512, genres: ['romance', 'novela'], description: 'Una joven acepta cuidar a un hombre que quedó tetrapléjico y ambos cambian su forma de ver la vida.'),
  CatalogBook(id: 'local_043', title: 'Los siete maridos de Evelyn Hugo', author: 'Taylor Jenkins Reid', pageCount: 400, genres: ['romance', 'novela'], description: 'Una legendaria actriz de Hollywood decide contar por fin la verdad sobre su vida y sus matrimonios.'),
  CatalogBook(id: 'local_044', title: 'La tregua', author: 'Mario Benedetti', pageCount: 192, genres: ['romance', 'novela'], description: 'El diario de un oficinista viudo a punto de jubilarse que inesperadamente vuelve a enamorarse.'),
  // Novela histórica y clásicos
  CatalogBook(id: 'local_050', title: 'Los pilares de la Tierra', author: 'Ken Follett', pageCount: 1040, genres: ['historica'], description: 'La construcción de una catedral en la Inglaterra del siglo XII une los destinos de constructores, monjes y nobles.'),
  CatalogBook(id: 'local_051', title: 'La casa de los espíritus', author: 'Isabel Allende', pageCount: 496, genres: ['historica', 'novela'], description: 'Saga de la familia Trueba a lo largo de cuatro generaciones, con el Chile del siglo XX como telón de fondo.'),
  CatalogBook(id: 'local_052', title: 'Inés del alma mía', author: 'Isabel Allende', pageCount: 400, genres: ['historica'], description: 'Inés Suárez relata su vida y su papel en la conquista y fundación de Santiago de Chile.'),
  CatalogBook(id: 'local_053', title: 'Cien años de soledad', author: 'Gabriel García Márquez', pageCount: 496, genres: ['clasicos', 'novela'], description: 'La historia de los Buendía y del pueblo de Macondo, obra central del realismo mágico.'),
  CatalogBook(id: 'local_054', title: 'Don Quijote de la Mancha', author: 'Miguel de Cervantes', pageCount: 1376, genres: ['clasicos'], description: 'Un hidalgo que ha leído demasiados libros de caballería sale a recorrer el mundo junto a Sancho Panza.'),
  CatalogBook(id: 'local_055', title: 'Crimen y castigo', author: 'Fiódor Dostoievski', pageCount: 672, genres: ['clasicos', 'novela', 'filosofia'], description: 'Un estudiante comete un asesinato convencido de que está justificado, y enfrenta el peso de su conciencia.'),
  CatalogBook(id: 'local_056', title: 'El principito', author: 'Antoine de Saint-Exupéry', pageCount: 96, genres: ['clasicos', 'juvenil', 'filosofia'], description: 'Un piloto perdido en el desierto conoce a un pequeño príncipe que le habla de su planeta y de lo esencial.'),
  CatalogBook(id: 'local_057', title: 'Rayuela', author: 'Julio Cortázar', pageCount: 736, genres: ['clasicos', 'novela'], description: 'Una novela que puede leerse en distintos órdenes y sigue a Horacio Oliveira entre París y Buenos Aires.'),
  CatalogBook(id: 'local_058', title: 'Pedro Páramo', author: 'Juan Rulfo', pageCount: 128, genres: ['clasicos', 'novela'], description: 'Juan Preciado viaja a Comala para buscar a su padre y encuentra un pueblo habitado por voces.'),
  CatalogBook(id: 'local_059', title: 'Los detectives salvajes', author: 'Roberto Bolaño', pageCount: 624, genres: ['novela'], description: 'Dos poetas buscan el rastro de una escritora desaparecida en un recorrido por México y el mundo.'),
  CatalogBook(id: 'local_060', title: 'Kafka en la orilla', author: 'Haruki Murakami', pageCount: 608, genres: ['novela', 'fantasia'], description: 'Un adolescente que huye de casa y un anciano que habla con gatos recorren caminos que terminan cruzándose.'),
  CatalogBook(id: 'local_061', title: 'Tokio blues', author: 'Haruki Murakami', pageCount: 384, genres: ['novela', 'romance'], description: 'Toru recuerda su juventud en Tokio y su relación con dos mujeres muy distintas.'),
  // Juvenil
  CatalogBook(id: 'local_070', title: 'Los juegos del hambre', author: 'Suzanne Collins', pageCount: 400, genres: ['juvenil', 'ciencia_ficcion'], description: 'Katniss se ofrece como tributo en un cruel espectáculo televisado donde solo puede sobrevivir uno.'),
  CatalogBook(id: 'local_071', title: 'Percy Jackson y el ladrón del rayo', author: 'Rick Riordan', pageCount: 384, genres: ['juvenil', 'fantasia'], description: 'Un adolescente descubre que es hijo de un dios griego y debe recuperar el rayo robado de Zeus.'),
  // Poesía
  CatalogBook(id: 'local_080', title: 'Veinte poemas de amor y una canción desesperada', author: 'Pablo Neruda', pageCount: 112, genres: ['poesia', 'romance', 'clasicos'], description: 'El poemario más leído de Neruda, sobre el deseo, la ausencia y el amor juvenil.'),
  CatalogBook(id: 'local_081', title: 'Desolación', author: 'Gabriela Mistral', pageCount: 200, genres: ['poesia', 'clasicos'], description: 'Primer libro de la poeta chilena, con versos sobre el dolor, la fe, la maternidad y el paisaje.'),
  CatalogBook(id: 'local_082', title: 'Poemas y antipoemas', author: 'Nicanor Parra', pageCount: 160, genres: ['poesia'], description: 'La obra que inauguró la antipoesía: humor, ironía y lenguaje cotidiano.'),
  // Cómic
  CatalogBook(id: 'local_090', title: 'Persépolis', author: 'Marjane Satrapi', pageCount: 352, genres: ['comic', 'biografia'], description: 'Novela gráfica autobiográfica sobre crecer en Irán durante y después de la revolución islámica.'),
  CatalogBook(id: 'local_091', title: 'Maus', author: 'Art Spiegelman', pageCount: 296, genres: ['comic', 'historia'], description: 'El autor reconstruye la experiencia de su padre en el Holocausto en una novela gráfica histórica.'),
  CatalogBook(id: 'local_092', title: 'Toda Mafalda', author: 'Quino', pageCount: 640, genres: ['comic'], description: 'Recopilación de las tiras de Mafalda, la niña que cuestiona el mundo de los adultos.'),
  // Biografías
  CatalogBook(id: 'local_100', title: 'Steve Jobs', author: 'Walter Isaacson', pageCount: 656, genres: ['biografia', 'tecnologia'], description: 'Biografía autorizada del cofundador de Apple, basada en decenas de entrevistas.'),
  CatalogBook(id: 'local_101', title: 'El diario de Ana Frank', author: 'Ana Frank', pageCount: 352, genres: ['biografia', 'historia', 'clasicos'], description: 'El diario de una adolescente judía escondida en Ámsterdam durante la ocupación nazi.'),
  CatalogBook(id: 'local_102', title: 'Yo soy Malala', author: 'Malala Yousafzai', pageCount: 336, genres: ['biografia'], description: 'La historia de la joven paquistaní que defendió el derecho de las niñas a la educación.'),
  // Historia
  CatalogBook(id: 'local_110', title: 'Sapiens: de animales a dioses', author: 'Yuval Noah Harari', pageCount: 496, genres: ['historia', 'ciencia'], description: 'Un recorrido por la historia de la humanidad, desde los primeros homínidos hasta la revolución científica.'),
  CatalogBook(id: 'local_111', title: 'Armas, gérmenes y acero', author: 'Jared Diamond', pageCount: 592, genres: ['historia', 'ciencia'], description: 'Por qué algunas sociedades dominaron a otras: geografía, agricultura y enfermedades.'),
  CatalogBook(id: 'local_112', title: 'SPQR: una historia de la antigua Roma', author: 'Mary Beard', pageCount: 608, genres: ['historia'], description: 'La historia de Roma desde sus orígenes míticos hasta la ciudadanía universal.'),
  // Ciencia
  CatalogBook(id: 'local_120', title: 'Breve historia del tiempo', author: 'Stephen Hawking', pageCount: 256, genres: ['ciencia'], description: 'Una explicación accesible del origen del universo, los agujeros negros y la naturaleza del tiempo.'),
  CatalogBook(id: 'local_121', title: 'Cosmos', author: 'Carl Sagan', pageCount: 384, genres: ['ciencia'], description: 'Un viaje por la historia de la ciencia y nuestro lugar en el universo.'),
  CatalogBook(id: 'local_122', title: 'El gen egoísta', author: 'Richard Dawkins', pageCount: 360, genres: ['ciencia'], description: 'La evolución vista desde el punto de vista de los genes.'),
  CatalogBook(id: 'local_123', title: 'El origen de las especies', author: 'Charles Darwin', pageCount: 512, genres: ['ciencia', 'clasicos'], description: 'La obra que presentó la teoría de la evolución por selección natural.'),
  // Desarrollo personal y psicología
  CatalogBook(id: 'local_130', title: 'Hábitos atómicos', author: 'James Clear', pageCount: 328, genres: ['desarrollo_personal'], description: 'Cómo pequeños cambios sostenidos en el tiempo producen grandes resultados.'),
  CatalogBook(id: 'local_131', title: 'Los 7 hábitos de la gente altamente efectiva', author: 'Stephen R. Covey', pageCount: 432, genres: ['desarrollo_personal', 'negocios'], description: 'Principios para la efectividad personal y profesional.'),
  CatalogBook(id: 'local_132', title: 'El poder del ahora', author: 'Eckhart Tolle', pageCount: 224, genres: ['desarrollo_personal', 'filosofia'], description: 'Una guía para vivir el presente y liberarse del pensamiento compulsivo.'),
  CatalogBook(id: 'local_133', title: 'Enfócate (Deep Work)', author: 'Cal Newport', pageCount: 304, genres: ['desarrollo_personal', 'tecnologia'], description: 'Por qué el trabajo profundo y sin distracciones es una habilidad cada vez más valiosa.'),
  CatalogBook(id: 'local_134', title: 'Pensar rápido, pensar despacio', author: 'Daniel Kahneman', pageCount: 672, genres: ['psicologia', 'negocios'], description: 'Los dos sistemas que gobiernan nuestra forma de pensar y los sesgos que provocan.'),
  CatalogBook(id: 'local_135', title: 'El hombre en busca de sentido', author: 'Viktor Frankl', pageCount: 168, genres: ['psicologia', 'filosofia', 'biografia'], description: 'Un psiquiatra sobreviviente de los campos de concentración reflexiona sobre el sentido de la vida.'),
  CatalogBook(id: 'local_136', title: 'Inteligencia emocional', author: 'Daniel Goleman', pageCount: 512, genres: ['psicologia', 'desarrollo_personal'], description: 'Por qué la gestión de las emociones puede ser tan importante como el coeficiente intelectual.'),
  // Filosofía
  CatalogBook(id: 'local_140', title: 'Meditaciones', author: 'Marco Aurelio', pageCount: 256, genres: ['filosofia', 'clasicos'], description: 'Reflexiones personales del emperador romano, base del estoicismo práctico.'),
  CatalogBook(id: 'local_141', title: 'El mundo de Sofía', author: 'Jostein Gaarder', pageCount: 640, genres: ['filosofia', 'novela', 'juvenil'], description: 'Una adolescente recibe cartas misteriosas que la introducen en la historia de la filosofía.'),
  CatalogBook(id: 'local_142', title: 'Así habló Zaratustra', author: 'Friedrich Nietzsche', pageCount: 400, genres: ['filosofia', 'clasicos'], description: 'La obra poética y filosófica en la que Nietzsche presenta al superhombre.'),
  // Negocios y tecnología
  CatalogBook(id: 'local_150', title: 'Padre rico, padre pobre', author: 'Robert T. Kiyosaki', pageCount: 336, genres: ['negocios', 'desarrollo_personal'], description: 'Lecciones de educación financiera a partir de dos figuras paternas opuestas.'),
  CatalogBook(id: 'local_151', title: 'El método Lean Startup', author: 'Eric Ries', pageCount: 336, genres: ['negocios', 'tecnologia'], description: 'Cómo crear empresas exitosas mediante experimentación, aprendizaje validado e iteración.'),
  CatalogBook(id: 'local_152', title: 'La psicología del dinero', author: 'Morgan Housel', pageCount: 256, genres: ['negocios', 'psicologia'], description: 'Historias breves sobre cómo pensamos y actuamos frente al dinero.'),
  CatalogBook(id: 'local_160', title: 'Código limpio', author: 'Robert C. Martin', pageCount: 464, genres: ['tecnologia'], description: 'Buenas prácticas para escribir código legible, mantenible y profesional.'),
  CatalogBook(id: 'local_161', title: 'El programador pragmático', author: 'Andrew Hunt, David Thomas', pageCount: 352, genres: ['tecnologia'], description: 'Consejos prácticos para desarrollar software de calidad y crecer como profesional.'),
  CatalogBook(id: 'local_162', title: 'Homo Deus', author: 'Yuval Noah Harari', pageCount: 496, genres: ['tecnologia', 'historia', 'filosofia'], description: 'Una mirada al futuro de la humanidad frente a la biotecnología y los algoritmos.'),
];

/// Busca en el catálogo local por título o autor (sin conexión).
/// [query] puede venir con tildes o mayúsculas.
List<CatalogBook> searchLocalCatalog(String query) {
  final normalized = normalizeText(query);
  if (normalized.isEmpty) return const [];
  return localCatalog
      .where((book) =>
          normalizeText('${book.title} ${book.author}').contains(normalized))
      .toList();
}

CatalogBook? localCatalogById(String id) {
  for (final book in localCatalog) {
    if (book.id == id) return book;
  }
  return null;
}
