(() => {
  'use strict';
  // Only finished, public encyclopaedia pages. Restricted records are added
  // from archive_content after its RLS policy has filtered the current user.
  const publicDossiers = [
    'Dan.html', 'Darius_Tom_I.html', 'Harvos.html', 'Milena.html',
    'Filk.html', 'Morgeus.html', 'Morell.html', 'Galdvin.html',
    'Sann.html', 'Forell.html', 'Hoffit.html', 'Gas.html',
    'Rogan.html', 'Ranor.html', 'Soren.html', 'Sorgen.html',
    'Erl.html', 'Karn.html', 'Konos.html', 'Norta.html',
    'Arkon.html', 'Anrirn.html', 'Adamantriy.html', 'Lienna.html',
    'Dorgus.html', 'Garaniy.html', 'Frauster_Kingdom.html',
    'Maizervin_Kingdom.html', 'Cult_Doronto.html'
  ];
  const restricted = {
    'magic-basics': 'Archive_Magic.html',
    'king-filk': 'Archive_Filk.html',
    'morgeus': 'Archive_Morgeus.html',
    'frauster-maizervin-feud': 'Archive_Frauster_Maizervin.html',
    'dokains-anatomy': 'Dokains_Archive.html',
    'artifact-will': 'Artifact_Will.html',
    'artifact-harvest': 'Artifact_Harvest.html',
    'artifact-elements': 'Artifact_Elements.html',
    'artifact-wishes': 'Artifact_Wishes.html',
    'artifact-dragons': 'Artifact_Dragons.html',
    'artifact-frauster-crown': 'Artifact_Frauster_Crown.html',
    'artifact-galdvin-crown': 'Artifact_Galdvin_Crown.html'
  };
  window.TODMDossiers = Object.freeze({ publicDossiers, restricted });
})();
