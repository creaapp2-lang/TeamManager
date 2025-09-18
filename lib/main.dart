// Flutter MVP "Gestione Squadre Sportive" — con fix su TabBar, Locale e Album
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  runApp(const SportTeamsApp());
}

class SportTeamsApp extends StatelessWidget {
  const SportTeamsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestione Squadre',
      locale: const Locale('it'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const HomePage(),
    );
  }
}

// ===================== MODELS =====================
class Team {
  String id;
  String name;
  final List<Athlete> athletes;
  final List<MatchGame> games;
  final List<Album> albums;
  Team({
    required this.id,
    required this.name,
    List<Athlete>? athletes,
    List<MatchGame>? games,
    List<Album>? albums,
  })  : athletes = athletes ?? [],
        games = games ?? [],
        albums = albums ?? [];

  int get yellowCount {
    final warnAth = athletes.where((a) => a.status == AthleteStatus.warn || a.status == AthleteStatus.miss).length;
    return warnAth;
  }

  int get redCount {
    final altAth = athletes.where((a) => a.status == AthleteStatus.alt).length;
    return altAth;
  }
}

class Athlete {
  String id;
  String firstName;
  String lastName;

  DateTime? medicalCertExpiry;
  String? phone;
  String? shirtSize;
  String? shortSize;
  String? role;
  DateTime? selfCertExpiry;
  String? idCardNumber;
  String? idCardImagePath;
  String? taxCode;
  String? taxCodeImagePath;
  int? jerseyNumber;
  String? matricola;
  DateTime? birthDate;
  bool membership = false;
  bool iscrizione = false;

  Athlete({required this.id, required this.firstName, required this.lastName});

  AthleteStatus get status {
    final missing = _hasMissingData();
    final alt = _hasExpired();
    final warn = _hasExpiringWithin(days: 30);
    if (alt) return AthleteStatus.alt;
    if (missing) return AthleteStatus.miss;
    if (warn) return AthleteStatus.warn;
    return AthleteStatus.ok;
  }

  bool _hasMissingData() {
    return ![
      firstName.isNotEmpty,
      lastName.isNotEmpty,
      medicalCertExpiry != null,
      selfCertExpiry != null,
      taxCode != null && taxCode!.isNotEmpty,
    ].every((e) => e);
  }

  bool _hasExpired() {
    final now = DateTime.now();
    bool expired(DateTime? d) => d != null && d.isBefore(DateTime(now.year, now.month, now.day));
    return expired(medicalCertExpiry) || expired(selfCertExpiry);
  }

  bool _hasExpiringWithin({required int days}) {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: days));
    bool expiring(DateTime? d) =>
        d != null && !d.isBefore(DateTime(now.year, now.month, now.day)) && d.isBefore(threshold);
    return expiring(medicalCertExpiry) || expiring(selfCertExpiry);
  }
}

enum AthleteStatus { ok, miss, warn, alt }

class MatchGame {
  String id;
  DateTime dateTime;
  String opponent;
  String league;
  String location;
  String? notes;
  MatchGame({
    required this.id,
    required this.dateTime,
    required this.opponent,
    required this.league,
    required this.location,
    this.notes,
  });
  String teamVs() => 'vs $opponent';
}

class Album {
  String id;
  String name;
  final List<String> imagePaths;
  Album({required this.id, required this.name, List<String>? imagePaths}) : imagePaths = imagePaths ?? [];
}

// ===================== STORE IN-MEMORY =====================
class AppStore extends ChangeNotifier {
  final List<Team> teams = [];
  void addTeam(String name) {
    teams.add(Team(id: UniqueKey().toString(), name: name));
    notifyListeners();
  }
  void renameTeam(Team team, String name) { team.name = name; notifyListeners(); }
  void removeTeam(Team team) { teams.remove(team); notifyListeners(); }
  void addAthlete(Team team, Athlete a) { team.athletes.add(a); notifyListeners(); }
  void updateAthlete(Team team) { notifyListeners(); }
  void addGame(Team team, MatchGame g) { team.games.add(g); notifyListeners(); }
  void addAlbum(Team team, Album a) { team.albums.add(a); notifyListeners(); }
}

// ===================== HOME =====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final store = AppStore();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Le mie squadre')),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: store.teams.isEmpty
              ? const Center(child: Text('Nessuna squadra, aggiungine una!'))
              : ListView.separated(
                  itemCount: store.teams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final t = store.teams[i];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Row(children: [
                          _pill(Colors.amber, 'Gialle', t.yellowCount),
                          const SizedBox(width: 8),
                          _pill(Colors.red, 'Rosse', t.redCount),
                        ]),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openTeam(t),
                      ),
                    );
                  },
                ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addTeamDialog,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi'),
        ),
      ),
    );
  }

  Widget _pill(Color color, String label, int count) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label: $count'),
        ]),
      );

  void _addTeamDialog() async {
    final c = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuova squadra'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nome squadra'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Crea')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) setState(() => store.addTeam(name));
  }

  void _openTeam(Team team) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamPage(team: team, store: store)));
  }
}

// ===================== TEAM PAGE (TABS) =====================
class TeamPage extends StatefulWidget {
  final Team team;
  final AppStore store;
  const TeamPage({super.key, required this.team, required this.store});
  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(widget.team.name),
        actions: [
          IconButton(icon: const Icon(Icons.settings), tooltip: 'Modifica nome squadra', onPressed: _renameTeam),
          IconButton(icon: const Icon(Icons.add), tooltip: 'Aggiungi', onPressed: _onAddInCurrentTab),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dati'),
            Tab(text: 'Gare'),
            Tab(text: 'Album'),
            Tab(text: 'Scouting'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DatiTab(team: widget.team, store: widget.store),
          _GareTab(team: widget.team, store: widget.store),
          _AlbumTab(team: widget.team, store: widget.store, onCreate: _addAlbum),
          const _ScoutingTab(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            onPressed: _onAddInCurrentTab,
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi'),
          ),
        ),
      ),
    );
  }

  void _renameTeam() async {
    final c = TextEditingController(text: widget.team.name);
    final newName = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifica nome squadra'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nome squadra'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Salva')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) setState(() => widget.store.renameTeam(widget.team, newName));
  }

  void _onAddInCurrentTab() {
    final idx = _tabController.index;
    if (idx == 0) _addAthlete();
    if (idx == 1) _addGame();
    if (idx == 2) _addAlbum();
    if (idx == 3) _showComingSoon();
  }

  void _addAthlete() async {
    final a = await Navigator.of(context).push<Athlete?>(MaterialPageRoute(builder: (_) => const AthleteEditPage()));
    if (a != null) setState(() => widget.store.addAthlete(widget.team, a));
  }

  void _addGame() async {
    final g = await Navigator.of(context).push<MatchGame?>(MaterialPageRoute(builder: (_) => const GameEditPage()));
    if (g != null) setState(() => widget.store.addGame(widget.team, g));
  }

  void _addAlbum() async {
    final controller = TextEditingController();
    final alb = await showDialog<Album?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuovo album'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nome album')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, Album(id: UniqueKey().toString(), name: controller.text.trim())), child: const Text('Crea')),
        ],
      ),
    );
    if (alb != null && alb.name.isNotEmpty) setState(() => widget.store.addAlbum(widget.team, alb));
  }

  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scouting'),
        content: const Text('Coming soon…'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

// ===================== TAB: DATI =====================
class _DatiTab extends StatelessWidget {
  final Team team;
  final AppStore store;
  const _DatiTab({required this.team, required this.store});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: team.athletes.isEmpty
          ? const Center(child: Text('Nessuna atleta. Aggiungi con "+"'))
          : ListView.separated(
              itemCount: team.athletes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = team.athletes[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text('${a.firstName} ${a.lastName}'),
                    subtitle: Row(children: _statusLabels(a.status)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AthleteDetailPage(athlete: a, onChanged: () => store.updateAthlete(team)),
                    )),
                  ),
                );
              },
            ),
    );
  }

  List<Widget> _statusLabels(AthleteStatus status) => [
        _statusChip('OK', Colors.green, status == AthleteStatus.ok),
        _statusChip('Miss', Colors.blue, status == AthleteStatus.miss),
        _statusChip('Warn', Colors.amber, status == AthleteStatus.warn),
        _statusChip('ALT!', Colors.red, status == AthleteStatus.alt),
      ];

  Widget _statusChip(String text, Color color, bool active) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.black54)),
        ),
      );
}

// ===================== ATLETA: DETTAGLIO =====================
class AthleteDetailPage extends StatefulWidget {
  final Athlete athlete;
  final VoidCallback onChanged;
  const AthleteDetailPage({super.key, required this.athlete, required this.onChanged});
  @override
  State<AthleteDetailPage> createState() => _AthleteDetailPageState();
}

class _AthleteDetailPageState extends State<AthleteDetailPage> {
  late Athlete a;
  final df = DateFormat('dd/MM/yyyy');
  @override
  void initState() {
    super.initState();
    a = widget.athlete;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('${a.firstName} ${a.lastName}'),
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _editBasic)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          _infoRow('Scadenza Cert. Medico', a.medicalCertExpiry == null ? '-' : df.format(a.medicalCertExpiry!)),
          _dateButton('Imposta', (d) => setState(() => a.medicalCertExpiry = d)),
          const Divider(),
          _infoRow('Cellulare', a.phone ?? '-'),
          Row(children: [
            ElevatedButton.icon(
              onPressed: a.phone == null ? null : _callNumber,
              icon: const Icon(Icons.phone),
              label: const Text('Chiama'),
            ),
          ]),
          const Divider(),
          _infoRow('Taglia Maglia/Calzone', '${a.shirtSize ?? '-'} / ${a.shortSize ?? '-'}'),
          _infoRow('Ruolo', a.role ?? '-'),
          const Divider(),
          _infoRow('Scadenza Autocertificazione', a.selfCertExpiry == null ? '-' : df.format(a.selfCertExpiry!)),
          _dateButton('Imposta', (d) => setState(() => a.selfCertExpiry = d)),
          const Divider(),
          _docRow('Carta d\'identità', a.idCardNumber, onNumber: (v) => a.idCardNumber = v),
          _docRow('Codice Fiscale', a.taxCode, onNumber: (v) => a.taxCode = v),
          const Divider(),
          _infoRow('Numero Maglia', a.jerseyNumber?.toString() ?? '-'),
          ElevatedButton(
              onPressed: () async {
                final v = await _numberDialog('Numero maglia');
                if (v != null) setState(() => a.jerseyNumber = v);
              },
              child: const Text('Imposta')),
          const Divider(),
          _infoRow('Matricola', a.matricola ?? '-'),
          ElevatedButton(
              onPressed: () async {
                final t = await _textDialog('Matricola', a.matricola);
                if (t != null) setState(() => a.matricola = t);
              },
              child: const Text('Imposta')),
          const Divider(),
          _infoRow('Data di nascita', a.birthDate == null ? '-' : df.format(a.birthDate!)),
          _dateButton('Imposta', (d) => setState(() => a.birthDate = d)),
          const Divider(),
          SwitchListTile(title: const Text('Tesseramento'), value: a.membership, onChanged: (v) => setState(() => a.membership = v)),
          SwitchListTile(title: const Text('Iscrizione'), value: a.iscrizione, onChanged: (v) => setState(() => a.iscrizione = v)),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: () { widget.onChanged(); Navigator.pop(context); },
            child: const Text('Salva'),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => ListTile(title: Text(label), subtitle: Text(value));

  Widget _dateButton(String label, ValueChanged<DateTime> onPick) => Row(children: [
        ElevatedButton(
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(1900), lastDate: DateTime(2100));
            if (d != null) onPick(d);
          },
          child: Text(label),
        ),
      ]);

  Future<int?> _numberDialog(String title) async {
    final c = TextEditingController(text: a.jerseyNumber?.toString() ?? '');
    final t = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    if (t == null || t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<String?> _textDialog(String title, String? initial) async {
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  void _editBasic() async {
    final first = await _textDialog('Nome', a.firstName);
    if (first != null) setState(() => a.firstName = first);
    final last = await _textDialog('Cognome', a.lastName);
    if (last != null) setState(() => a.lastName = last);
  }

  void _callNumber() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Chiamata diretta: integrare url_launcher')));
  }
}

Widget _docRow(String label, String? number, {required ValueChanged<String> onNumber}) {
  final controller = TextEditingController(text: number ?? '');
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    TextField(controller: controller, decoration: const InputDecoration(hintText: 'Numero documento'), onChanged: onNumber),
  ]);
}

// ===================== TAB: GARE =====================
class _GareTab extends StatefulWidget {
  final Team team;
  final AppStore store;
  const _GareTab({required this.team, required this.store});
  @override
  State<_GareTab> createState() => _GareTabState();
}

class _GareTabState extends State<_GareTab> {
  final df = DateFormat('EEE dd/MM yyyy – HH:mm', 'it_IT');
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(children: [
        Row(children: [
          ElevatedButton.icon(onPressed: _addGame, icon: const Icon(Icons.add), label: const Text('Nuova gara')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _copyNext7Days, icon: const Icon(Icons.copy), label: const Text('Copia 7gg')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _syncGoogleCalendar, icon: const Icon(Icons.calendar_month), label: const Text('Google Calendar')),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: widget.team.games.isEmpty
              ? const Center(child: Text('Nessuna gara'))
              : ListView.separated(
                  itemCount: widget.team.games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final g = widget.team.games[i];
                    return Card(
                      child: ListTile(
                        title: Text('${g.opponent} • ${g.league}'),
                        subtitle: Text('${df.format(g.dateTime)}\n${g.location}${g.notes == null || g.notes!.isEmpty ? '' : '\nNote: ${g.notes}'}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _addGame() async {
    final g = await Navigator.of(context).push<MatchGame?>(MaterialPageRoute(builder: (_) => const GameEditPage()));
    if (g != null) setState(() => widget.store.addGame(widget.team, g));
  }

  void _copyNext7Days() {
    final now = DateTime.now();
    final till = now.add(const Duration(days: 7));
    final games = widget.team.games.where((g) => g.dateTime.isAfter(now) && g.dateTime.isBefore(till)).toList();
    if (games.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nessuna partita nei prossimi 7 giorni')));
      return;
    }
    final lines = games.map((g) => '- ${DateFormat('dd/MM HH:mm').format(g.dateTime)} ${g.league}: ${g.teamVs()} @ ${g.location}').join('\n');
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Copia e incolla'), content: SingleChildScrollView(child: Text(lines)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))]));
  }

  void _syncGoogleCalendar() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizzazione Google Calendar: stub')));
  }
}

class GameEditPage extends StatefulWidget {
  const GameEditPage({super.key});
  @override
  State<GameEditPage> createState() => _GameEditPageState();
}

class _GameEditPageState extends State<GameEditPage> {
  final opponentC = TextEditingController();
  final leagueC = TextEditingController();
  final locationC = TextEditingController();
  final notesC = TextEditingController();
  DateTime? date;
  TimeOfDay? time;
  final df = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova gara')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          ListTile(title: const Text('Data'), trailing: ElevatedButton(onPressed: _pickDate, child: Text(date == null ? 'Seleziona' : df.format(date!)))),
          ListTile(title: const Text('Orario'), trailing: ElevatedButton(onPressed: _pickTime, child: Text(time == null ? 'Seleziona' : time!.format(context)))),
          const SizedBox(height: 8),
          TextField(controller: opponentC, decoration: const InputDecoration(labelText: 'Squadra avversaria')),
          const SizedBox(height: 8),
          TextField(controller: leagueC, decoration: const InputDecoration(labelText: 'Campionato')),
          const SizedBox(height: 8),
          TextField(controller: locationC, decoration: const InputDecoration(labelText: 'Luogo')),
          const SizedBox(height: 8),
          TextField(controller: notesC, decoration: const InputDecoration(labelText: 'Note'), maxLines: 3),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(onPressed: _save, child: const Text('Salva')),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now.subtract(const Duration(days: 3650)), lastDate: now.add(const Duration(days: 3650)));
    if (d != null) setState(() => date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => time = t);
  }

  void _save() {
    if (date == null || time == null || opponentC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compila data, orario e avversaria')));
      return;
    }
    final dt = DateTime(date!.year, date!.month, date!.day, time!.hour, time!.minute);
    final g = MatchGame(
      id: UniqueKey().toString(),
      dateTime: dt,
      opponent: opponentC.text.trim(),
      league: leagueC.text.trim(),
      location: locationC.text.trim(),
      notes: notesC.text.trim(),
    );
    Navigator.pop(context, g);
  }
}

// ===================== TAB: ALBUM =====================
class _AlbumTab extends StatelessWidget {
  final Team team;
  final AppStore store;
  final VoidCallback onCreate;
  const _AlbumTab({required this.team, required this.store, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(children: [
        Row(children: [
          ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Crea album')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: () => _shareAlbum(context), icon: const Icon(Icons.link), label: const Text('Condividi link')),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: team.albums.isEmpty
              ? const Center(child: Text('Nessun album'))
              : ListView.separated(
                  itemCount: team.albums.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = team.albums[i];
                    return Card(
                      child: ListTile(
                        title: Text(a.name),
                        subtitle: Text('${a.imagePaths.length} immagini'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumPage(album: a))),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _shareAlbum(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Condivisione: implementare backend/storage')));
  }
}

class AlbumPage extends StatelessWidget {
  final Album album;
  const AlbumPage({super.key, required this.album});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(album.name)),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.photo_library, size: 72),
          const SizedBox(height: 12),
          Text('Galleria: ${album.imagePaths.length} immagini'),
          const SizedBox(height: 12),
          Wrap(spacing: 10, children: [
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload), label: const Text('Carica immagine')),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.photo_camera), label: const Text('Scatta foto')),
          ]),
        ]),
      ),
    );
  }
}

// ===================== TAB: SCOUTING =====================
class _ScoutingTab extends StatelessWidget {
  const _ScoutingTab();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Coming soon…'));
}

// ===================== ATLETA: CREAZIONE =====================
class AthleteEditPage extends StatefulWidget {
  const AthleteEditPage({super.key});
  @override
  State<AthleteEditPage> createState() => _AthleteEditPageState();
}

class _AthleteEditPageState extends State<AthleteEditPage> {
  final firstC = TextEditingController();
  final lastC = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova atleta')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          TextField(controller: firstC, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 8),
          TextField(controller: lastC, decoration: const InputDecoration(labelText: 'Cognome')),
          const Spacer(),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: () {
              if (firstC.text.trim().isEmpty || lastC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e Cognome sono obbligatori')));
                return;
              }
              final a = Athlete(id: UniqueKey().toString(), firstName: firstC.text.trim(), lastName: lastC.text.trim());
              Navigator.pop(context, a);
            },
            child: const Text('Crea'),
          ),
        ),
      ),
    );
  }
}
