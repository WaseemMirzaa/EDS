import '../../models/drug_catalog_entry.dart';
import '../../models/enums.dart';
import '../../models/instructions.dart';

/// A starter catalog of ophthalmic medications, bundled with the app.
///
/// Two jobs:
///   * gives [LocalDrugMatcher] something to resolve against with no network,
///     which is the common case when someone is scanning a bottle in a pharmacy;
///   * seeds the server-side `drug_catalog` table on first deploy.
///
/// Aliases include the generic name and the mis-reads OCR reliably produces on
/// small curved label text — 'rn' for 'm', '0' for 'O', dropped spaces.
///
/// This is reference data for recognition and pre-fill convenience only. It
/// carries no dosing recommendation: [typicalFrequency] exists to save typing,
/// and the user confirms every value before a schedule is created.
const List<DrugCatalogEntry> kDrugCatalogSeed = [
  // ---------------------------------------------------------------- antibiotics
  DrugCatalogEntry(
    id: 'seed-vigamox',
    brandName: 'Vigamox',
    genericName: 'Moxifloxacin',
    strength: '0.5%',
    form: 'solution',
    category: Category.antibiotic,
    defaultCapColor: 'blue',
    typicalFrequency: FrequencyType.fourDaily,
    typicalInstructions: Instructions(wait5min: true, pressTearDuct: true),
    aliases: ['moxifloxacin', 'vigarnox', 'vigamoxx', 'moxeza'],
  ),
  DrugCatalogEntry(
    id: 'seed-tobradex',
    brandName: 'Tobradex',
    genericName: 'Tobramycin / Dexamethasone',
    strength: '0.3% / 0.1%',
    form: 'suspension',
    category: Category.antibiotic,
    defaultCapColor: 'tan',
    typicalFrequency: FrequencyType.fourDaily,
    typicalInstructions: Instructions(shake: true, wait5min: true),
    aliases: ['tobramycin dexamethasone', 'tobra dex', 'tobradexx'],
  ),

  // -------------------------------------------------------------------- steroids
  DrugCatalogEntry(
    id: 'seed-pred-forte',
    brandName: 'Pred Forte',
    genericName: 'Prednisolone acetate',
    strength: '1%',
    form: 'suspension',
    category: Category.steroid,
    defaultCapColor: 'pink',
    typicalFrequency: FrequencyType.fourDaily,
    typicalInstructions: Instructions(shake: true, wait5min: true, pressTearDuct: true),
    requiresTaper: true,
    aliases: ['prednisolone', 'predforte', 'pred-forte', 'prednisolone acetate'],
  ),
  DrugCatalogEntry(
    id: 'seed-durezol',
    brandName: 'Durezol',
    genericName: 'Difluprednate',
    strength: '0.05%',
    form: 'emulsion',
    category: Category.steroid,
    defaultCapColor: 'pink',
    typicalFrequency: FrequencyType.fourDaily,
    typicalInstructions: Instructions(shake: true, wait5min: true),
    requiresTaper: true,
    aliases: ['difluprednate', 'durezoll'],
  ),

  // ---------------------------------------------------------------------- NSAIDs
  DrugCatalogEntry(
    id: 'seed-acular',
    brandName: 'Acular',
    genericName: 'Ketorolac tromethamine',
    strength: '0.5%',
    form: 'solution',
    category: Category.nsaid,
    defaultCapColor: 'gray',
    typicalFrequency: FrequencyType.fourDaily,
    typicalInstructions: Instructions(wait5min: true),
    aliases: ['ketorolac', 'acuvail', 'accular'],
  ),
  DrugCatalogEntry(
    id: 'seed-ilevro',
    brandName: 'Ilevro',
    genericName: 'Nepafenac',
    strength: '0.3%',
    form: 'suspension',
    category: Category.nsaid,
    defaultCapColor: 'gray',
    typicalFrequency: FrequencyType.onceDaily,
    typicalInstructions: Instructions(shake: true, wait5min: true),
    aliases: ['nepafenac', 'nevanac', 'ilevr0'],
  ),

  // ------------------------------------------------------------ artificial tears
  DrugCatalogEntry(
    id: 'seed-systane',
    brandName: 'Systane',
    genericName: 'Polyethylene glycol / Propylene glycol',
    form: 'solution',
    category: Category.artificialTears,
    defaultCapColor: 'white',
    typicalFrequency: FrequencyType.customTimes,
    typicalInstructions: Instructions(removeContacts: true),
    aliases: ['systane ultra', 'systane balance', 'systarie', 'artificial tears'],
  ),
  DrugCatalogEntry(
    id: 'seed-refresh',
    brandName: 'Refresh Tears',
    genericName: 'Carboxymethylcellulose',
    form: 'solution',
    category: Category.artificialTears,
    defaultCapColor: 'white',
    typicalFrequency: FrequencyType.customTimes,
    typicalInstructions: Instructions(removeContacts: true),
    aliases: ['refresh', 'carboxymethylcellulose', 'refresh optive'],
  ),
  DrugCatalogEntry(
    id: 'seed-hylo',
    brandName: 'Hylo Gel',
    genericName: 'Sodium hyaluronate',
    form: 'gel',
    category: Category.artificialTears,
    defaultCapColor: 'white',
    typicalFrequency: FrequencyType.customTimes,
    aliases: ['hylo', 'hylo-gel', 'sodium hyaluronate', 'hylo dual'],
  ),

  // -------------------------------------------------------------------- glaucoma
  DrugCatalogEntry(
    id: 'seed-xalatan',
    brandName: 'Xalatan',
    genericName: 'Latanoprost',
    strength: '0.005%',
    form: 'solution',
    category: Category.glaucoma,
    defaultCapColor: 'teal',
    typicalFrequency: FrequencyType.onceDaily,
    typicalInstructions: Instructions(refrigerate: true, pressTearDuct: true),
    aliases: ['latanoprost', 'xalatarr', 'monoprost'],
  ),
  DrugCatalogEntry(
    id: 'seed-timoptic',
    brandName: 'Timoptic',
    genericName: 'Timolol maleate',
    strength: '0.5%',
    form: 'solution',
    category: Category.glaucoma,
    defaultCapColor: 'blue',
    typicalFrequency: FrequencyType.twiceDaily,
    typicalInstructions: Instructions(pressTearDuct: true),
    aliases: ['timolol', 'timoptic-xe', 'tirnoptic'],
  ),
  DrugCatalogEntry(
    id: 'seed-combigan',
    brandName: 'Combigan',
    genericName: 'Brimonidine / Timolol',
    form: 'solution',
    category: Category.glaucoma,
    // Combigan's real cap is purple; the app's palette is the eight colours in
    // kCapColors, so it maps to the nearest available and the user can change it.
    defaultCapColor: 'gray',
    typicalFrequency: FrequencyType.twiceDaily,
    typicalInstructions: Instructions(pressTearDuct: true),
    aliases: ['brimonidine timolol', 'cornbigan'],
  ),

  // ----------------------------------------------------------------------- other
  DrugCatalogEntry(
    id: 'seed-restasis',
    brandName: 'Restasis',
    genericName: 'Cyclosporine',
    strength: '0.05%',
    form: 'emulsion',
    category: Category.other,
    defaultCapColor: 'white',
    typicalFrequency: FrequencyType.twiceDaily,
    typicalInstructions: Instructions(removeContacts: true),
    aliases: ['cyclosporine', 'restasls', 'cequa', 'verkazia'],
  ),
];
