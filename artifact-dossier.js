(() => {
  'use strict';
  const root = document.querySelector('[data-artifact-dossier]');
  if (!root) return;
  const entries = {
    will: { slug: 'artifact-will', code: '01', level: 0, tone: 'will' },
    harvest: { slug: 'artifact-harvest', code: '02', level: 0, tone: 'harvest' },
    elements: { slug: 'artifact-elements', code: '03', level: 0, tone: 'elements' },
    wishes: { slug: 'artifact-wishes', code: '04', level: 1, tone: 'wishes' },
    dragons: { slug: 'artifact-dragons', code: '05', level: 0, tone: 'dragons' },
    frauster: { slug: 'artifact-frauster-crown', code: '06', level: 0, tone: 'frauster' },
    galdvin: { slug: 'artifact-galdvin-crown', code: '07', level: 1, tone: 'galdvin' }
  };
  const entry = entries[root.dataset.artifactDossier];
  if (!entry) return;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const back = '<a class="artifact-back" href="Artifacts_Tom_I.html">← НАЗАД К АРТЕФАКТАМ</a>';
  const paragraphs = values => (values || []).map(value => `<p>${esc(value)}</p>`).join('');
  function renderWill() {
    const facts = [
      ['Тип', 'Палаш / клинковое оружие'],
      ['Известный владелец', 'Дан'],
      ['Материал клинка', 'Обсидиан'],
      ['Рукоять', 'Драконья кожа'],
      ['Особенность', 'Сам выбирает владельца']
    ];
    const properties = [
      ['Выбор владельца', 'Меч Воли самостоятельно определяет человека, которому должен принадлежать, и способен оказаться на его пути.'],
      ['Адаптация', 'Оружие способно приспосабливаться к своему владельцу.'],
      ['Связь с владельцем', 'После установления связи владелец способен призывать меч к себе усилием мысли.'],
      ['Воля', 'Проявления силы Меча Воли связаны с внутренним состоянием и волей владельца.'],
      ['Жар и пламя', 'В определённых состояниях клинок способен проявлять свойства, связанные с сильным нагревом и пламенем.']
    ];
    const construction = [
      ['Клинок', 'Широкий обсидиановый клинок.'],
      ['Материал', 'Обсидиан, происходящий из районов потухших вулканов.'],
      ['Рукоять', 'Отделана драконьей кожей.'],
      ['Золотая часть', 'Позволяет наносить монашеские руны.'],
      ['Форма', 'Массивный широкий палаш. Ширина клинка позволяет использовать оружие для частичной защиты.']
    ];
    root.innerHTML = `<article class="artifact-dossier artifact-dossier--will artifact-dossier--feature">
      <header class="artifact-feature-hero">
        <div class="artifact-feature-hero__inner">
          <div class="artifact-feature-hero__copy">
            <nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span aria-hidden="true">→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span aria-hidden="true">→</span><span aria-current="page">Меч Воли</span></nav>
            <p class="eyebrow">Досье 01 · Артефакт / оружие</p>
            <h1>Меч Воли</h1>
            <p class="artifact-feature-hero__lead">Оружие, которое само находит своего владельца.</p>
            ${back}
          </div>
          <figure class="artifact-feature-hero__art"><a href="images/will-sword.png" target="_blank" rel="noopener" aria-label="Открыть изображение Меча Воли в полном размере"><img src="images/will-sword.png" alt="Художественное изображение Меча Воли: широкий клинок в сиянии пламени" width="998" height="1575" fetchpriority="high"></a><figcaption>01 / Меч Воли · открыть изображение ↗</figcaption></figure>
        </div>
      </header>
      <div class="artifact-feature-body">
        <section class="artifact-feature-facts" aria-labelledby="will-facts-title"><div class="artifact-feature-section-head"><p class="eyebrow">Архивная запись / 01</p><h2 id="will-facts-title">Краткое досье</h2></div><dl>${facts.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section artifact-feature-intro" aria-labelledby="will-description-title"><div class="artifact-feature-section-head"><p class="eyebrow">I / Описание</p><h2 id="will-description-title">Меч Воли</h2></div><div class="artifact-feature-prose"><p>Меч Воли — необычный клинок, известным владельцем которого является паладин Дан.</p><p>Оружие представляет собой широкий палаш с обсидиановым клинком. Обсидиан для подобных клинков добывается в районе потухших вулканов. Рукоять Меча Воли обтянута драконьей кожей, а золотая часть оружия позволяет наносить на неё монашеские руны.</p><p>Клинок отличается значительной шириной и массивностью. Его конструкция позволяет использовать оружие не только для нанесения ударов: широкий клинок способен частично выполнять функцию защиты.</p><p>Однако главная особенность Меча Воли связана не с его конструкцией. <strong>Артефакт сам выбирает того, кому должен принадлежать.</strong></p></div></section>
        <section class="artifact-feature-choice" aria-labelledby="will-choice-title"><div class="artifact-feature-section-head"><p class="eyebrow">II / Наблюдаемый эффект</p><h2 id="will-choice-title">Меч выбирает владельца</h2></div><div class="artifact-feature-prose"><p>Меч Воли не обязательно попадает к новому владельцу обычным путём. Когда артефакт выбирает человека, он способен самостоятельно оказаться на его пути.</p><p>Будущий владелец может обнаружить клинок, например, в лавке оружейника. При этом сам оружейник будет совершенно уверен, что этот меч находился среди его товаров всегда.</p><p>В другой ситуации Меч Воли может оказаться у человека, который впоследствии передаст его будущему владельцу в качестве подарка. Тот, кто передаёт оружие, также будет уверен, что клинок уже давно находился в его распоряжении.</p><p>Таким образом, появление Меча Воли не воспринимается окружающими как нечто невозможное. Артефакт словно становится естественной частью обстоятельств, которые приводят его к выбранному владельцу.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="will-properties-title"><div class="artifact-feature-section-head"><p class="eyebrow">III / Зафиксированные свойства</p><h2 id="will-properties-title">Свойства</h2></div><div class="artifact-feature-properties">${properties.map(([label, value], index) => `<article><span aria-hidden="true">0${index + 1}</span><h3>${esc(label)}</h3><p>${esc(value)}</p></article>`).join('')}</div></section>
        <section class="artifact-feature-section" aria-labelledby="will-construction-title"><div class="artifact-feature-section-head"><p class="eyebrow">IV / Предметное описание</p><h2 id="will-construction-title">Конструкция</h2></div><dl class="artifact-feature-construction">${construction.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <figure class="artifact-feature-owner"><a href="images/dan-will-sword.png" target="_blank" rel="noopener" aria-label="Открыть изображение Дана с Мечом Воли в полном размере"><img src="images/dan-will-sword.png" alt="Художественное изображение паладина Дана с Мечом Воли" width="538" height="850" loading="lazy"></a><figcaption><span>Известный владелец</span><strong>Дан</strong><a href="Dan.html">Досье: Дан ↗</a></figcaption></figure>
        <aside class="artifact-feature-note" aria-labelledby="will-note-title"><p class="eyebrow">Архивная заметка</p><h2 id="will-note-title">Механизм не установлен</h2><p>Неизвестно, каким образом Меч Воли оказывается на пути выбранного владельца и почему люди, через которых проходит артефакт, воспринимают его присутствие как естественное.</p><p>Наблюдаемый эффект не позволяет достоверно определить, изменяет ли артефакт окружающие обстоятельства или воздействует на их восприятие.</p></aside>
        <div class="artifact-feature-end">${back}<a href="Tom_I.html">Перейти к Тому I ↗</a></div>
      </div>
    </article>`;
  }
  function renderHarvest() {
    const facts = [
      ['Тип', 'Клинковое оружие'],
      ['Создатель', 'Форелл'],
      ['Известный владелец', 'Дариус'],
      ['Характерное проявление', 'Фиолетовое свечение'],
      ['Основное свойство', 'Поглощение жизненной энергии'],
      ['Опасность', 'Способен представлять угрозу владельцу']
    ];
    const properties = [
      ['Поглощение жизненной энергии', 'Меч способен вытягивать жизненную энергию живого существа через нанесённую им рану.'],
      ['Последствия ранения', 'Опасность удара определяется не только тяжестью физического повреждения. Продолжающееся воздействие Меча Жатвы способно привести раненого к смерти.'],
      ['Разрушительная сила', 'Меч обладает достаточной силой, чтобы разрушать другое клинковое оружие.'],
      ['Предупреждение', 'Меч способен реагировать на приближающуюся опасность характерной вибрацией, предупреждая Дариуса.'],
      ['Прекращение воздействия', 'Когда оружие убирают в ножны, его активное воздействие прекращается.']
    ];
    const construction = [
      ['Рукоять', 'Чёрная рукоять, обмотанная фиолетовой тканью.'],
      ['Клинок', 'Единый клинок необычной конструкции, разделённый на две части.'],
      ['Серебристый камень', 'В конструкции оружия присутствует серебристый камень.'],
      ['Кристалл', 'Между двумя частями клинка расположен фиолетовый кристалл, визуально словно зависший внутри оружия.'],
      ['Энергия', 'Проявление свойств Меча Жатвы сопровождается характерным фиолетовым свечением.']
    ];
    root.innerHTML = `<article class="artifact-dossier artifact-dossier--harvest artifact-dossier--feature">
      <header class="artifact-feature-hero">
        <div class="artifact-feature-hero__inner">
          <div class="artifact-feature-hero__copy">
            <nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span aria-hidden="true">→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span aria-hidden="true">→</span><span aria-current="page">Меч Жатвы</span></nav>
            <p class="eyebrow">Досье 02 · Артефакт / оружие</p><h1>Меч Жатвы</h1>
            <p class="artifact-feature-hero__lead">Оружие, способное поглощать жизненную энергию через нанесённую им рану.</p>
            ${back}
          </div>
          <figure class="artifact-feature-hero__art"><a href="images/harvest-sword.png" target="_blank" rel="noopener" aria-label="Открыть изображение Меча Жатвы в полном размере"><img src="images/harvest-sword.png" alt="Один меч с разделённым на две части клинком и фиолетовым свечением" width="941" height="1672" fetchpriority="high"></a><figcaption>02 / Меч Жатвы · открыть изображение ↗</figcaption></figure>
        </div>
      </header>
      <div class="artifact-feature-body">
        <section class="artifact-feature-facts" aria-labelledby="harvest-facts-title"><div class="artifact-feature-section-head"><p class="eyebrow">Архивная запись / 02</p><h2 id="harvest-facts-title">Краткое досье</h2></div><dl>${facts.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section" aria-labelledby="harvest-description-title"><div class="artifact-feature-section-head"><p class="eyebrow">I / Описание</p><h2 id="harvest-description-title">Меч Жатвы</h2></div><div class="artifact-feature-prose"><p>Меч Жатвы — необычное оружие, созданное Фореллом и впоследствии переданное Дариусу.</p><p>Внешний облик меча столь же необычен, как и его свойства. Чёрная рукоять обмотана фиолетовой тканью. В конструкции присутствует серебристый камень, а единый клинок имеет необычную форму и разделён на две части. Между ними находится фиолетовый кристалл, визуально словно зависший внутри оружия.</p><p>Проявление силы Меча Жатвы сопровождается характерным фиолетовым свечением.</p><p>Однако главная особенность оружия заключается не в его конструкции. <strong>Меч Жатвы способен забирать жизненную энергию живого существа через нанесённую им рану.</strong></p></div></section>
        <section class="artifact-feature-choice artifact-harvest-reaping" aria-labelledby="harvest-reaping-title"><div class="artifact-feature-section-head"><p class="eyebrow">II / Основное воздействие</p><h2 id="harvest-reaping-title">Жатва</h2></div><div class="artifact-feature-prose"><p>Повреждение, нанесённое Мечом Жатвы, опасно не только само по себе.</p><p>После того как клинок достигает противника, оружие начинает вытягивать через нанесённую рану его жизненную энергию.</p><p>Даже ранение, которое при столкновении с обычным оружием могло бы оказаться переживаемым, под воздействием Меча Жатвы способно привести к смерти.</p><p>Физическое повреждение становится лишь началом воздействия клинка.</p><p>Именно способность продолжать отнимать жизненную энергию через оставленную рану делает Меч Жатвы значительно опаснее обычного оружия.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="harvest-properties-title"><div class="artifact-feature-section-head"><p class="eyebrow">III / Зафиксированные свойства</p><h2 id="harvest-properties-title">Свойства</h2></div><div class="artifact-feature-properties">${properties.map(([label, value], index) => `<article><span aria-hidden="true">0${index + 1}</span><h3>${esc(label)}</h3><p>${esc(value)}</p></article>`).join('')}</div></section>
        <section class="artifact-harvest-warning" aria-labelledby="harvest-warning-title"><div class="artifact-feature-section-head"><p class="eyebrow">IV / Предупреждение Архива</p><h2 id="harvest-warning-title">Оружие, опасное для владельца</h2></div><div class="artifact-feature-prose"><p>Меч Жатвы нельзя считать полностью безопасным даже в руках того, кому он принадлежит.</p><p>Способность оружия поглощать жизненную энергию делает неосторожное обращение с клинком потенциально опасным и для самого владельца.</p><p>Использование Меча Жатвы требует постоянного понимания природы оружия и осторожности при контакте с ним.</p><p>Убрать меч в ножны — один из способов прекратить его активное воздействие.</p><div class="artifact-harvest-warning__callout"><strong>Предупреждение Архива</strong><span>Свойства Меча Жатвы потенциально опасны не только для противника. Неосторожный контакт с оружием способен представлять угрозу для его владельца.</span></div></div></section>
        <section class="artifact-feature-section" aria-labelledby="harvest-construction-title"><div class="artifact-feature-section-head"><p class="eyebrow">V / Предметное описание</p><h2 id="harvest-construction-title">Конструкция</h2></div><dl class="artifact-feature-construction">${construction.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section artifact-harvest-creator" aria-labelledby="harvest-creator-title"><div class="artifact-feature-section-head"><p class="eyebrow">VI / Создатель</p><h2 id="harvest-creator-title">Форелл</h2></div><div class="artifact-feature-prose"><p>Создателем Меча Жатвы является Форелл — один из докаинов, занимавшийся созданием и изучением необычных предметов.</p><p>Именно Форелл дал оружию название «Меч Жатвы», после чего клинок оказался у Дариуса.</p><a class="artifact-feature-link" href="Forell.html">Досье: Форелл ↗</a></div></section>
        <figure class="artifact-feature-owner artifact-harvest-owner"><a href="images/darius-harvest-sword.png" target="_blank" rel="noopener" aria-label="Открыть изображение Дариуса с Мечом Жатвы в полном размере"><img src="images/darius-harvest-sword.png" alt="Художественное изображение Дариуса с одним Мечом Жатвы" width="1023" height="1537" loading="lazy"></a><figcaption><span>Известный владелец</span><strong>Дариус</strong><a href="Darius_Tom_I.html">Досье: Дариус ↗</a></figcaption><p>После создания оружия Фореллом клинок оказался в распоряжении Дариуса.</p></figure>
        <aside class="artifact-feature-note artifact-harvest-note" aria-labelledby="harvest-note-title"><p class="eyebrow">Архивная заметка</p><h2 id="harvest-note-title">После ранения</h2><p>Физическое повреждение является лишь началом воздействия Меча Жатвы.</p><p><strong>Основную угрозу представляет то, что происходит после того, как клинок оставляет рану.</strong></p></aside>
        <div class="artifact-feature-end">${back}<a href="Tom_I.html">Перейти к Тому I ↗</a></div>
      </div>
    </article>`;
  }
  function renderDragons() {
    const facts = [
      ['Тип', 'Длинный клинок'],
      ['Известный владелец', 'Лиенна'],
      ['Материал', 'Неизвестный металл желтоватого оттенка'],
      ['Происхождение', 'Связан с Драконьей горой'],
      ['Характерное проявление', 'Огонь и сильный жар']
    ];
    const properties = [
      ['Огненный клинок', 'При активации сила меча проявляется в виде огня, окружающего клинок.'],
      ['Жар', 'Активное оружие способно выделять чрезвычайно сильное тепло.'],
      ['Огненные атаки', 'Лиенна способна использовать силу меча для направленных огненных атак.'],
      ['Огненная сфера', 'Одним из известных проявлений силы оружия является формирование огненной сферы.'],
      ['Ограничение активации', 'Сила меча доступна не каждому, кто способен физически взять оружие в руки. Известно, что Дариус не смог активировать его свойства.']
    ];
    const construction = [
      ['Клинок', 'Длинный клинок, формой напоминающий катану.'],
      ['Металл', 'Оружие изготовлено из неизвестного металла желтоватого оттенка.'],
      ['Рукоять', 'Рукоять выполнена в чёрном цвете.'],
      ['Дракон', 'В конструкции оружия присутствует золотая фигура дракона.'],
      ['Глаза', 'Глаза дракона выполнены из красных камней.']
    ];
    root.innerHTML = `<article class="artifact-dossier artifact-dossier--dragons artifact-dossier--feature">
      <header class="artifact-feature-hero">
        <div class="artifact-feature-hero__inner">
          <div class="artifact-feature-hero__copy">
            <nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span aria-hidden="true">→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span aria-hidden="true">→</span><span aria-current="page">Меч драконов</span></nav>
            <p class="eyebrow">Досье 05 · Артефакт / оружие</p><h1>Меч драконов</h1>
            <p class="artifact-feature-hero__lead">Оружие с Драконьей горы, способное пробуждать разрушительную силу огня.</p>
            ${back}
          </div>
          <figure class="artifact-feature-hero__art"><a href="images/dragons-sword.png" target="_blank" rel="noopener" aria-label="Открыть изображение Меча драконов в полном размере"><img src="images/dragons-sword.png" alt="Меч драконов на переднем плане разрушенного города; Лиенна видна вдали" width="853" height="1280" fetchpriority="high"></a><figcaption>05 / Меч драконов · открыть изображение ↗</figcaption></figure>
        </div>
      </header>
      <div class="artifact-feature-body">
        <section class="artifact-feature-facts" aria-labelledby="dragons-facts-title"><div class="artifact-feature-section-head"><p class="eyebrow">Архивная запись / 05</p><h2 id="dragons-facts-title">Краткое досье</h2></div><dl>${facts.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section" aria-labelledby="dragons-description-title"><div class="artifact-feature-section-head"><p class="eyebrow">I / Описание</p><h2 id="dragons-description-title">Меч драконов</h2></div><div class="artifact-feature-prose"><p>Меч драконов — необычное оружие, оказавшееся у Лиенны после её обращения к драконам.</p><p>Клинок прибыл к ней с Драконьей горы. Его появление стало ответом на обращение Лиенны, однако точное происхождение оружия, обстоятельства его создания и прежняя история остаются неизвестными.</p><p>Меч представляет собой длинный клинок, напоминающий катану. Он изготовлен из неизвестного металла желтоватого оттенка и имеет чёрную рукоять.</p><p>Одной из наиболее заметных деталей оружия является золотая фигура дракона. Его глаза выполнены в виде красных камней.</p><p>Уже при первом контакте с оружием Лиенна почувствовала исходящее от него приятное тепло.</p><p>Но настоящий характер меча раскрывается при его использовании.</p></div></section>
        <section class="artifact-feature-choice artifact-dragons-gift" aria-labelledby="dragons-gift-title"><div class="artifact-feature-section-head"><p class="eyebrow">II / Обстоятельства появления</p><h2 id="dragons-gift-title">Дар драконов</h2></div><div class="artifact-feature-prose"><p>Меч не был найден Лиенной среди обычного оружия и не был получен от другого человека.</p><p>После обращения Лиенны к драконам клинок прибыл к ней с Драконьей горы.</p><p>Именно обстоятельства его появления позволяют связывать оружие с драконами, однако многое о природе артефакта остаётся неизвестным.</p><p>Кто создал меч, когда он был создан и существовали ли до Лиенны другие его владельцы — неизвестно.</p></div></section>
        <section class="artifact-feature-section artifact-dragons-fire" aria-labelledby="dragons-fire-title"><div class="artifact-feature-section-head"><p class="eyebrow">III / Проявление силы</p><h2 id="dragons-fire-title">Огонь</h2></div><div class="artifact-feature-prose"><p>Главное известное проявление силы Меча драконов связано с огнём.</p><p>При использовании клинок способен раскаляться и окружаться ярким пламенем. Его сила позволяет Лиенне применять огонь непосредственно в бою, значительно расширяя возможности обычного клинкового оружия.</p><p>Меч способен не только покрываться пламенем. С его помощью Лиенна может направлять огненную силу против противника, в том числе формируя мощные огненные атаки.</p><p>Одним из известных проявлений является огненная сфера.</p><p>Высокая температура становится самостоятельным свойством активного оружия: меч способен выделять чрезвычайно сильный жар.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="dragons-properties-title"><div class="artifact-feature-section-head"><p class="eyebrow">IV / Зафиксированные свойства</p><h2 id="dragons-properties-title">Свойства</h2></div><div class="artifact-feature-properties">${properties.map(([label, value], index) => `<article><span aria-hidden="true">0${index + 1}</span><h3>${esc(label)}</h3><p>${esc(value)}</p></article>`).join('')}</div></section>
        <section class="artifact-dragons-limit" aria-labelledby="dragons-limit-title"><div class="artifact-feature-section-head"><p class="eyebrow">V / Граница наблюдений</p><h2 id="dragons-limit-title">Не каждому подчиняется его сила</h2></div><div class="artifact-feature-prose"><p>Наличие Меча драконов в руках ещё не означает возможность воспользоваться его силой.</p><p><a href="Darius_Tom_I.html">Дариус</a> пытался активировать оружие, однако меч не проявил для него тех свойств, которые демонстрировал в руках Лиенны.</p><p><strong>Причина этого ограничения неизвестна.</strong></p></div></section>
        <section class="artifact-feature-section" aria-labelledby="dragons-construction-title"><div class="artifact-feature-section-head"><p class="eyebrow">VI / Предметное описание</p><h2 id="dragons-construction-title">Конструкция</h2></div><dl class="artifact-feature-construction">${construction.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <figure class="artifact-feature-owner artifact-dragons-owner"><a href="images/lienna-dragons-sword.png" target="_blank" rel="noopener" aria-label="Открыть изображение Лиенны с Мечом драконов в полном размере"><img src="images/lienna-dragons-sword.png" alt="Лиенна применяет охваченный пламенем Меч драконов в бою" width="851" height="1280" loading="lazy"></a><figcaption><span>Известный владелец</span><strong>Лиенна</strong><a href="Lienna.html">Досье: Лиенна ↗</a></figcaption><p>Меч драконов находится в распоряжении Лиенны и демонстрирует свои необычные свойства именно при использовании ею.</p><p>Использование оружия связано с человеческим обликом Лиенны. Помещение меча в ножны сопровождается возвращением Лиенны в облик докаина.</p></figure>
        <aside class="artifact-feature-note artifact-dragons-note" aria-labelledby="dragons-note-title"><p class="eyebrow">Архивная заметка</p><h2 id="dragons-note-title">Происхождение неизвестно</h2><p>Установлено, что оружие прибыло к Лиенне с Драконьей горы после её обращения к драконам и способно проявлять в её руках значительную огненную силу.</p><p>Почему те же свойства не удалось пробудить Дариусу — неизвестно.</p><p>Архив не располагает сведениями о том, кто и с какой целью создал этот клинок.</p></aside>
        <div class="artifact-feature-end">${back}<a href="Tom_I.html">Перейти к Тому I ↗</a></div>
      </div>
    </article>`;
  }
  function renderFrausterCrown() {
    const facts = [
      ['Тип', 'Королевская реликвия'],
      ['Известный владелец', 'Король Филк'],
      ['Принадлежность', 'Короли Фраустера'],
      ['Происхождение', 'Дар Мартли королям Фраустера'],
      ['Характерное проявление', 'Белая / светлая энергия'],
      ['Основное свойство', 'Взаимодействие с мёртвыми']
    ];
    const properties = [
      ['Общение с мёртвыми', 'Королевская сила позволяет устанавливать контакт с умершими и говорить с ними.'],
      ['Воздействие на недавно умерших', 'При определённых условиях сила короны позволяет королю воздействовать на недавно умерших и получать над ними власть.'],
      ['Светлая энергия', 'Проявление силы сопровождается белой, светлой энергией.'],
      ['Истощение', 'Использование короны требует значительных сил от короля.'],
      ['Обратное воздействие', 'Мёртвые, с которыми устанавливается связь, способны воздействовать на сознание самого короля.']
    ];
    root.innerHTML = `<article class="artifact-dossier artifact-dossier--frauster artifact-dossier--feature">
      <header class="artifact-feature-hero">
        <div class="artifact-feature-hero__inner">
          <div class="artifact-feature-hero__copy">
            <nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span aria-hidden="true">→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span aria-hidden="true">→</span><span aria-current="page">Корона Фраустера</span></nav>
            <p class="eyebrow">Досье 06 · Артефакт / королевская реликвия</p><h1>Корона Фраустера</h1>
            <p class="artifact-feature-hero__lead">Королевская реликвия, позволяющая живому обратиться к мёртвым.</p>
            ${back}
          </div>
          <figure class="artifact-feature-hero__art"><a href="images/frauster-crown.png" target="_blank" rel="noopener" aria-label="Открыть изображение Короны Фраустера в полном размере"><img src="images/frauster-crown.png" alt="Предметный арт Короны Фраустера на нейтральном фоне" width="1254" height="1254" fetchpriority="high"></a><figcaption>06 / Корона Фраустера · открыть изображение ↗</figcaption></figure>
        </div>
      </header>
      <div class="artifact-feature-body">
        <section class="artifact-feature-facts" aria-labelledby="frauster-facts-title"><div class="artifact-feature-section-head"><p class="eyebrow">Архивная запись / 06</p><h2 id="frauster-facts-title">Краткое досье</h2></div><dl>${facts.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section" aria-labelledby="frauster-description-title"><div class="artifact-feature-section-head"><p class="eyebrow">I / Описание</p><h2 id="frauster-description-title">Корона Фраустера</h2></div><div class="artifact-feature-prose"><p>Корона Фраустера — королевская реликвия, передаваемая вместе с властью над королевством.</p><p>Её значение выходит далеко за пределы обычного символа монархии. С короной связана способность правителя обращаться к мёртвым.</p><p>Согласно известным сведениям, корона была дарована королям Фраустера Мартли.</p></div></section>
        <section class="artifact-feature-choice artifact-frauster-gift" aria-labelledby="frauster-gift-title"><div class="artifact-feature-section-head"><p class="eyebrow">II / Происхождение</p><h2 id="frauster-gift-title">Дар Мартли</h2></div><div class="artifact-feature-prose"><p>Корона — не просто знак власти правящей династии.</p><p>Её сила связана с Мартли и предназначена для королей Фраустера.</p><p>Королевская реликвия позволяет обратиться к тем, кто уже умер.</p></div></section>
        <section class="artifact-feature-choice artifact-frauster-voices" aria-labelledby="frauster-voices-title"><div class="artifact-feature-section-head"><p class="eyebrow">III / Основное проявление</p><h2 id="frauster-voices-title">Голоса мёртвых</h2></div><div class="artifact-feature-prose"><p>Корона позволяет королю Фраустера вступать в контакт с умершими.</p><p>Её сила даёт возможность говорить с мёртвыми, получая от них сведения, которые иначе были бы недоступны живым.</p><p>Однако возможности короны этим не ограничиваются.</p><p>При определённых условиях королевская сила позволяет воздействовать и на недавно умерших, получая над ними власть.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="frauster-king-title"><div class="artifact-feature-section-head"><p class="eyebrow">IV / Предел доступа</p><h2 id="frauster-king-title">Власть короля</h2></div><div class="artifact-feature-prose"><p>Сила короны не является обычной магией, которой способен воспользоваться любой человек.</p><p>Она связана с властью короля Фраустера.</p><p>Самого обладания реликвией недостаточно, чтобы автоматически получить доступ к её возможностям.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="frauster-properties-title"><div class="artifact-feature-section-head"><p class="eyebrow">V / Зафиксированные свойства</p><h2 id="frauster-properties-title">Свойства</h2></div><div class="artifact-feature-properties">${properties.map(([label, value], index) => `<article><span aria-hidden="true">0${index + 1}</span><h3>${esc(label)}</h3><p>${esc(value)}</p></article>`).join('')}</div></section>
        <section class="artifact-frauster-cost" aria-labelledby="frauster-cost-title"><div class="artifact-feature-section-head"><p class="eyebrow">VI / Риск использования</p><h2 id="frauster-cost-title">Цена использования</h2></div><div class="artifact-feature-prose"><p>Использование силы короны не проходит для короля бесследно.</p><p>Обращение к короне требует значительных сил и способно серьёзно истощать владельца.</p><p>Однако физическое истощение — не единственная опасность.</p><p>Контакт с умершими создаёт риск воздействия самих мёртвых на сознание короля.</p><p>Таким образом, попытка получить доступ к миру умерших представляет опасность и для того, кто использует королевскую силу.</p></div></section>
        <aside class="artifact-frauster-warning" aria-labelledby="frauster-warning-title"><p class="eyebrow">Предупреждение Архива</p><h2 id="frauster-warning-title">Контакт действует в обе стороны</h2><p>Использование королевской реликвии не означает абсолютной власти над смертью.</p><p>Пока король пытается обратиться к мёртвым, мёртвые способны оказывать влияние на него самого.</p></aside>
        <figure class="artifact-feature-owner artifact-frauster-owner"><a href="images/filk-frauster-crown.png" target="_blank" rel="noopener" aria-label="Открыть изображение короля Филка в полном размере"><img src="images/filk-frauster-crown.png" alt="Король Филк в короне Фраустера" width="538" height="850" loading="lazy"></a><figcaption><span>Известный владелец</span><strong>Король Филк</strong><a href="Filk.html">Досье: король Филк ↗</a></figcaption><p>Филк, король Фраустера, является известным владельцем короны и способен использовать заключённую в ней силу.</p></figure>
        <aside class="artifact-feature-note artifact-frauster-note" aria-labelledby="frauster-note-title"><p class="eyebrow">Архивная заметка</p><h2 id="frauster-note-title">Королевская власть</h2><p>Корона Фраустера является не только символом королевской власти.</p><p>Она позволяет действующему королю прикоснуться к тому, что обычно остаётся недоступным живым.</p><p>Однако власть над мёртвыми не является односторонней.</p><p><strong>Мёртвые также способны коснуться разума того, кто их призывает.</strong></p></aside>
        <div class="artifact-feature-end">${back}<a href="Tom_I.html">Перейти к Тому I ↗</a></div>
      </div>
    </article>`;
  }
  function renderElements() {
    const facts = [
      ['Тип', 'Магический инструмент'],
      ['Известный владелец', 'Моргеус'],
      ['Основное назначение', 'Сдерживание и поглощение избыточной магической силы'],
      ['Характерная особенность', 'Вращающиеся вокруг посоха камни'],
      ['Принцип', 'Контроль, а не усиление']
    ];
    const properties = [
      ['Поглощение', 'Посох способен принимать на себя часть магической силы Моргеуса.'],
      ['Сдерживание', 'Основное назначение артефакта — помогать контролировать огромный объём силы его владельца.'],
      ['Реакция камней', 'Камни, окружающие посох, ускоряют своё вращение по мере увеличения количества поглощаемой энергии.'],
      ['Рассеивание холода', 'Известно применение Посоха Стихий для противодействия воздействию холода.'],
      ['Обнаружение', 'Посох использовался Моргеусом при обнаружении скрытого присутствия разведчиков Майзервина.']
    ];
    const unknown = [
      'происхождении артефакта', 'его создателе', 'материале', 'природе окружающих его камней',
      'способе поглощения магической энергии', 'предельном количестве силы, которое способен принять посох'
    ];
    root.innerHTML = `<article class="artifact-dossier artifact-dossier--elements artifact-dossier--feature">
      <header class="artifact-elements-hero">
        <img class="artifact-elements-hero__image" src="images/elements-staff-hero.jpg" alt="Посох Стихий в магической сцене; вокруг него вращаются разноцветные камни" width="1672" height="941" fetchpriority="high">
        <div class="artifact-elements-hero__shade" aria-hidden="true"></div>
        <div class="artifact-elements-hero__inner">
          <nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span aria-hidden="true">→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span aria-hidden="true">→</span><span aria-current="page">Посох Стихий</span></nav>
          <div class="artifact-elements-hero__copy"><p class="eyebrow">Досье 03 · Артефакт / магический инструмент</p><h1>Посох Стихий</h1><p>Посох не является источником силы Моргеуса.<br><strong>Он существует для того, чтобы эту силу сдерживать.</strong></p>${back}</div>
        </div>
      </header>
      <div class="artifact-feature-body">
        <section class="artifact-elements-object" aria-labelledby="elements-object-title"><div class="artifact-elements-object__copy"><div class="artifact-feature-section-head"><p class="eyebrow">Объект Архива / 03</p><h2 id="elements-object-title">Посох Стихий</h2></div><p>Предметное изображение артефакта. Его устройство и происхождение не установлены.</p></div><figure><a href="images/elements-staff.jpg" target="_blank" rel="noopener" aria-label="Открыть предметное изображение Посоха Стихий в полном размере"><img src="images/elements-staff.jpg" alt="Посох Стихий на тёмном фоне; видны его форма и центральное свечение" width="1024" height="1536" loading="lazy"></a><figcaption>Предметный арт · открыть изображение ↗</figcaption></figure></section>
        <section class="artifact-feature-facts" aria-labelledby="elements-facts-title"><div class="artifact-feature-section-head"><p class="eyebrow">Архивная запись / 03</p><h2 id="elements-facts-title">Краткое досье</h2></div><dl>${facts.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section" aria-labelledby="elements-description-title"><div class="artifact-feature-section-head"><p class="eyebrow">I / Описание</p><h2 id="elements-description-title">Посох Стихий</h2></div><div class="artifact-feature-prose"><p>Посох Стихий — магический артефакт, используемый верховным магом Моргеусом.</p><p>Несмотря на огромную силу своего владельца, назначение посоха заключается не в её увеличении.</p><p>Он необходим Моргеусу, чтобы эту силу сдерживать.</p><p>Артефакт принимает на себя избыток магической энергии, позволяя Моргеусу контролировать собственную мощь.</p><p>Одной из наиболее заметных особенностей посоха являются камни, вращающиеся вокруг него. Их движение напрямую связано с количеством силы, которую артефакт вынужден поглощать.</p></div></section>
        <section class="artifact-feature-choice artifact-elements-restraint" aria-labelledby="elements-restraint-title"><div class="artifact-feature-section-head"><p class="eyebrow">II / Главное назначение</p><h2 id="elements-restraint-title">Не усилитель.<br>Ограничитель.</h2></div><div class="artifact-feature-prose"><p>Посох Стихий не является источником силы Моргеуса.</p><p>Он не делает верховного мага могущественнее.</p><p>Его назначение противоположно — поглощать избыток силы Моргеуса и помогать удерживать её под контролем.</p><p>Чем больше магической энергии принимает на себя посох, тем заметнее становится работа самого артефакта.</p></div></section>
        <section class="artifact-feature-section artifact-elements-stones" aria-labelledby="elements-stones-title"><div class="artifact-feature-section-head"><p class="eyebrow">III / Внешний признак нагрузки</p><h2 id="elements-stones-title">Вращающиеся камни</h2></div><div class="artifact-feature-prose"><p>Вокруг Посоха Стихий находятся камни, движение которых связано с работой артефакта.</p><p>Чем больше магической силы вынужден поглощать посох, тем быстрее они вращаются.</p><p>Таким образом, движение камней становится внешним признаком нагрузки, которую в данный момент принимает на себя артефакт.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="elements-morgeus-power-title"><div class="artifact-feature-section-head"><p class="eyebrow">IV / Владелец и сила</p><h2 id="elements-morgeus-power-title">Сила Моргеуса</h2></div><div class="artifact-feature-prose"><p>Моргеус обладает настолько значительной магической силой, что Посох Стихий используется прежде всего как средство её контроля.</p><p>Артефакт позволяет принимать на себя избыток энергии и тем самым сдерживать мощь верховного мага.</p><p>Поэтому присутствие посоха рядом с Моргеусом не следует воспринимать как признак зависимости мага от внешнего источника силы.</p><p><strong>Посох нужен не для того, чтобы Моргеус мог использовать больше магии. Он нужен, чтобы удерживать уже имеющуюся.</strong></p></div></section>
        <section class="artifact-feature-section" aria-labelledby="elements-properties-title"><div class="artifact-feature-section-head"><p class="eyebrow">V / Подтверждённые наблюдения</p><h2 id="elements-properties-title">Известные свойства</h2></div><div class="artifact-feature-properties">${properties.map(([label, value], index) => `<article><span aria-hidden="true">0${index + 1}</span><h3>${esc(label)}</h3><p>${esc(value)}</p></article>`).join('')}</div></section>
        <section class="artifact-feature-section artifact-elements-unknown" aria-labelledby="elements-unknown-title"><div class="artifact-feature-section-head"><p class="eyebrow">VI / Предел сведений</p><h2 id="elements-unknown-title">Неизвестное устройство</h2></div><div class="artifact-feature-prose"><p>Несмотря на известный принцип действия, устройство Посоха Стихий остаётся практически неизученным.</p><p>Архив не располагает достоверными сведениями о:</p><ul>${unknown.map(value => `<li>${esc(value)}</li>`).join('')}</ul></div></section>
        <figure class="artifact-feature-owner artifact-elements-owner"><a href="images/morgeus-elements-staff.jpg" target="_blank" rel="noopener" aria-label="Открыть изображение Моргеуса с Посохом Стихий в полном размере"><img src="images/morgeus-elements-staff.jpg" alt="Моргеус держит Посох Стихий" width="1024" height="1536" loading="lazy"></a><figcaption><span>Известный владелец</span><strong>Моргеус</strong><a href="Morgeus.html">Досье: Моргеус ↗</a></figcaption><p>Посох Стихий находится в распоряжении Моргеуса — верховного мага Фраустера.</p><p>Связь между магом и артефактом необычна именно своим назначением: Моргеус использует посох не для получения дополнительной силы, а для контроля над собственной.</p></figure>
        <aside class="artifact-feature-note artifact-elements-note" aria-labelledby="elements-note-title"><p class="eyebrow">Архивная заметка</p><h2 id="elements-note-title">Контроль вместо усиления</h2><p>Распространённое представление о магических посохах как об источниках или усилителях силы неприменимо к Посоху Стихий.</p><p>Известные наблюдения указывают на противоположное назначение артефакта: он принимает на себя часть силы своего владельца.</p><p>Скорость движения окружающих посох камней увеличивается вместе с объёмом поглощаемой энергии.</p><p><strong>Посох Стихий не делает Моргеуса сильнее. Он позволяет Моргеусу оставаться под контролем.</strong></p></aside>
        <div class="artifact-feature-end">${back}<a href="Tom_I.html">Перейти к Тому I ↗</a></div>
      </div>
    </article>`;
  }
  function renderWishes() {
    const facts = [
      ['Тип', 'Природа не установлена'],
      ['Местонахождение', 'Неизвестно'],
      ['Внешний вид', 'Неизвестен'],
      ['Создатель', 'Неизвестен'],
      ['Известное свойство', 'Исполнение желаний'],
      ['Предполагаемая стоимость', 'Неизвестна'],
      ['Источник сведений', 'Упоминание, обнаруженное Лиенной в древней библиотеке']
    ];
    const known = [
      ['Существование', 'Упоминание о Книге желаний было обнаружено Лиенной в древней библиотеке на Драконьей горе.'],
      ['Назначение', 'Согласно найденным сведениям, артефакт способен исполнять желания.'],
      ['Местонахождение', 'Текущее местонахождение Книги желаний неизвестно.']
    ];
    const unknown = [
      'внешнем виде Книги', 'её происхождении', 'создателе', 'возрасте', 'текущем местонахождении',
      'принципе действия', 'способе использования', 'ограничениях исполняемых желаний',
      'количестве возможных желаний', 'предполагаемой стоимости исполнения желания',
      'последствиях использования артефакта'
    ];
    root.innerHTML = `<article class="artifact-dossier artifact-dossier--wishes artifact-dossier--feature">
      <header class="artifact-wishes-hero"><div class="artifact-wishes-hero__inner">
        <nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span aria-hidden="true">→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span aria-hidden="true">→</span><span aria-current="page">Книга желаний</span></nav>
        <p class="eyebrow">Досье 04 · Артефакт / природа не установлена</p><h1>Книга желаний</h1>
        <p class="artifact-wishes-hero__lead">Артефакт, известный лишь по обнаруженному упоминанию о его способности исполнять желания.</p>
        ${back}
        <aside class="artifact-visual-unavailable artifact-wishes-visual" aria-label="Визуальная фиксация отсутствует"><span class="artifact-visual-unavailable__code">АРХИВ I / ЗАПИСЬ 04</span><span class="artifact-visual-unavailable__status">Визуальная фиксация отсутствует</span><p>Архив не располагает достоверными сведениями о внешнем виде Книги желаний. Ни одного подтверждённого изображения артефакта обнаружить не удалось.</p><p>Визуальная реконструкция не приводится, поскольку основывалась бы исключительно на предположениях.</p></aside>
      </div></header>
      <div class="artifact-feature-body artifact-wishes-body">
        <section class="artifact-feature-facts" aria-labelledby="wishes-facts-title"><div class="artifact-feature-section-head"><p class="eyebrow">Архивная запись / 04</p><h2 id="wishes-facts-title">Краткое досье</h2></div><dl>${facts.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section" aria-labelledby="wishes-description-title"><div class="artifact-feature-section-head"><p class="eyebrow">I / Описание</p><h2 id="wishes-description-title">Книга желаний</h2></div><div class="artifact-feature-prose"><p>Книга желаний — загадочный артефакт, существование которого известно лишь по найденному Лиенной упоминанию.</p><p>Сведения о Книге были обнаружены в древней библиотеке на Драконьей горе.</p><p>Согласно найденной информации, этот артефакт обладает невероятной способностью — исполнять желания.</p><p>На этом достоверные сведения практически заканчиваются.</p><p>Архив не располагает подтверждённой информацией о происхождении Книги желаний, её создателе, местонахождении, внешнем виде или принципе действия.</p></div></section>
        <section class="artifact-feature-choice artifact-wishes-mention" aria-labelledby="wishes-mention-title"><div class="artifact-feature-section-head"><p class="eyebrow">II / Источник сведений</p><h2 id="wishes-mention-title">Единственное упоминание</h2></div><div class="artifact-feature-prose"><p>Лиенна обнаружила сведения о Книге желаний при изучении древней библиотеки на Драконьей горе.</p><p>В найденных материалах упоминался невероятный артефакт, способный исполнять желания.</p><p>Где находилась Книга в момент обнаружения этих сведений — неизвестно.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="wishes-ability-title"><div class="artifact-feature-section-head"><p class="eyebrow">III / Указанное свойство</p><h2 id="wishes-ability-title">Исполнение желаний</h2></div><div class="artifact-feature-prose"><p>Согласно обнаруженным сведениям, Книга способна исполнять желания.</p><p>При этом Архив не располагает достаточной информацией, чтобы определить механизм действия артефакта.</p><p>Неизвестно, каким образом формулируется желание, существуют ли ограничения на его содержание и какие силы обеспечивают его исполнение.</p></div></section>
        <aside class="artifact-wishes-cost" aria-labelledby="wishes-cost-title"><p class="eyebrow">Поле архивного досье</p><h2 id="wishes-cost-title">Предполагаемая стоимость исполнения: <span>неизвестна</span></h2><p>Архив не располагает сведениями, позволяющими установить, требует ли исполнение желания какой-либо платы и какой она может быть.</p></aside>
        <section class="artifact-wishes-known" aria-labelledby="wishes-known-title"><div class="artifact-feature-section-head"><p class="eyebrow">IV / Подтверждённые сведения</p><h2 id="wishes-known-title">Что известно</h2></div><div class="artifact-feature-properties">${known.map(([label, value], index) => `<article><span aria-hidden="true">0${index + 1}</span><h3>${esc(label)}</h3><p>${esc(value)}</p></article>`).join('')}</div></section>
        <section class="artifact-wishes-unknown" aria-labelledby="wishes-unknown-title"><div class="artifact-feature-section-head"><p class="eyebrow">V / Данные отсутствуют</p><h2 id="wishes-unknown-title">Что неизвестно</h2></div><p>Архив не располагает подтверждёнными сведениями о:</p><ul>${unknown.map(value => `<li>${esc(value)}</li>`).join('')}</ul></section>
        <section class="artifact-feature-section artifact-wishes-source" aria-labelledby="wishes-source-title"><div class="artifact-feature-section-head"><p class="eyebrow">Источник сведений</p><h2 id="wishes-source-title">Лиенна</h2></div><div class="artifact-feature-prose"><p>Именно Лиенна обнаружила упоминание о Книге желаний в древней библиотеке на Драконьей горе.</p><p>На момент обнаружения записи местонахождение самого артефакта оставалось неизвестным.</p><a class="artifact-feature-link" href="Lienna.html">Досье: Лиенна ↗</a></div></section>
        <aside class="artifact-wishes-access" aria-labelledby="wishes-access-title"><p class="eyebrow">Допуск Архива I</p><h2 id="wishes-access-title">Ограниченные сведения</h2><p>Доступные сведения о Книге желаний крайне ограничены. Архив подтверждает существование упоминания об артефакте и содержащиеся в нём сведения о способности исполнять желания. Большая часть информации о Книге отсутствует.</p></aside>
        <aside class="artifact-feature-note artifact-wishes-note" aria-labelledby="wishes-note-title"><p class="eyebrow">Архивная заметка</p><h2 id="wishes-note-title">Предел сведений</h2><p>Книга желаний упоминается как артефакт, способный исполнять желания.</p><p>Где она находится, как выглядит и каким образом действует — неизвестно.</p><p>Архив также не располагает сведениями, позволяющими установить предполагаемую стоимость её использования.</p><p><strong>На данный момент существование записи о Книге известно значительно лучше, чем сама Книга.</strong></p></aside>
        <div class="artifact-feature-end">${back}<a href="Tom_I.html">Перейти к Тому I ↗</a></div>
      </div>
    </article>`;
  }
  function renderGaldvinCrown() {
    const facts = [
      ['Тип', 'Королевская реликвия'],
      ['Известный владелец', 'Король Галдвин'],
      ['Принадлежность', 'Майзервин'],
      ['Внешний вид', 'Не зафиксирован Архивом'],
      ['Известное проявление', 'Сильный холод'],
      ['Статус сведений', 'Ограниченные данные']
    ];
    const observations = [
      ['Холод', 'Непосредственный контакт с артефактом вызывает чрезвычайно сильное ощущение холода.'],
      ['Отголосок', 'При прикосновении Дариус на короткое время ощутил состояние Галдвина перед его смертью.'],
      ['Синий отблеск', 'Во время контакта было зафиксировано кратковременное изменение глаза Дариуса — появление синего отблеска.'],
      ['Неизвестная природа', 'Доступных сведений недостаточно, чтобы установить механизм действия короны и полный перечень её возможностей.']
    ];
    const unknown = [
      'происхождении короны', 'её создателе', 'времени создания', 'материале', 'внешнем виде',
      'полном перечне свойств', 'механизме появления отголоска Галдвина',
      'возможности проявления аналогичного эффекта с другими владельцами',
      'связи короны с магией Майзервина'
    ];
    root.innerHTML = `<article class="artifact-dossier artifact-dossier--galdvin artifact-dossier--feature">
      <header class="artifact-feature-hero"><div class="artifact-feature-hero__inner">
        <div class="artifact-feature-hero__copy">
          <nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span aria-hidden="true">→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span aria-hidden="true">→</span><span aria-current="page">Корона короля Галдвина</span></nav>
          <p class="eyebrow">Досье 07 · Артефакт / королевская реликвия</p><h1>Корона короля Галдвина</h1>
          <p class="artifact-feature-hero__lead">Реликвия Майзервина, внешний вид и природа которой остаются неизвестными Архиву.</p>${back}
        </div>
        <aside class="artifact-visual-unavailable" aria-label="Внешний вид короны не зафиксирован">
          <span class="artifact-visual-unavailable__code">АРХИВ I / ЗАПИСЬ 07</span>
          <span class="artifact-visual-unavailable__status">Визуальная фиксация · недоступна</span>
          <h2>Изображение отсутствует</h2>
          <p>Архиву не удалось получить достоверное изображение Короны короля Галдвина.</p>
          <p>Любая визуальная реконструкция артефакта основывалась бы на предположениях и потому не включена в досье.</p>
        </aside>
      </div></header>
      <div class="artifact-feature-body">
        <section class="artifact-feature-facts" aria-labelledby="galdvin-facts-title"><div class="artifact-feature-section-head"><p class="eyebrow">Архивная запись / 07</p><h2 id="galdvin-facts-title">Краткое досье</h2></div><dl>${facts.map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>
        <section class="artifact-feature-section" aria-labelledby="galdvin-description-title"><div class="artifact-feature-section-head"><p class="eyebrow">I / Описание</p><h2 id="galdvin-description-title">Корона короля Галдвина</h2></div><div class="artifact-feature-prose"><p>Корона короля Галдвина — одна из королевских реликвий Майзервина.</p><p>Архив располагает крайне ограниченными сведениями об этом артефакте. Его происхождение, устройство и полный перечень свойств остаются неизвестными.</p><p>Не удалось зафиксировать и внешний вид короны.</p><p>Большая часть доступных сведений основана на единственном известном проявлении её силы — непосредственном контакте Дариуса с артефактом.</p><p>Именно этот эпизод позволяет утверждать, что корона представляет собой нечто значительно большее, чем обычный символ королевской власти.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="galdvin-visual-title"><div class="artifact-feature-section-head"><p class="eyebrow">II / Статус материала</p><h2 id="galdvin-visual-title">Внешний вид не зафиксирован</h2></div><div class="artifact-feature-prose"><p>Архиву не удалось получить достоверное изображение Короны короля Галдвина.</p><p>Любая попытка визуально восстановить артефакт потребовала бы использования неподтверждённых предположений.</p><p>По этой причине реконструкция внешнего вида короны в досье отсутствует.</p></div></section>
        <section class="artifact-feature-choice artifact-galdvin-contact" aria-labelledby="galdvin-contact-title"><div class="artifact-feature-section-head"><p class="eyebrow">III / Единственный известный контакт</p><h2 id="galdvin-contact-title">Прикосновение</h2></div><div class="artifact-feature-prose"><p>Главный известный эпизод, связанный со свойствами короны, произошёл при прикосновении Дариуса к артефакту.</p><p>Контакт сопровождался резким и чрезвычайно сильным ощущением холода.</p><p>Однако холод оказался не единственным проявлением.</p><p>На краткий миг Дариус ощутил нечто, принадлежавшее не ему самому — отголосок состояния короля Галдвина перед смертью.</p><p>Эффект оказался непродолжительным, но сам факт подобного воздействия <strong>позволяет предположить</strong> наличие связи между короной и её владельцем.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="galdvin-echo-title"><div class="artifact-feature-section-head"><p class="eyebrow">IV / Наблюдение</p><h2 id="galdvin-echo-title">Отголосок владельца</h2></div><div class="artifact-feature-prose"><p>Во время контакта с короной Дариус на короткое мгновение ощутил состояние Галдвина перед его смертью.</p><p>Однако природа этого явления неизвестна.</p><p>Архив не располагает сведениями, позволяющими установить, что именно сохраняет или передаёт корона: память, эмоциональный след, остаточное воздействие владельца или нечто иное.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="galdvin-blue-title"><div class="artifact-feature-section-head"><p class="eyebrow">V / Наблюдение</p><h2 id="galdvin-blue-title">Синий отблеск</h2></div><div class="artifact-feature-prose"><p>Во время контакта с короной было замечено ещё одно необычное проявление — кратковременное изменение глаза Дариуса, в котором появился синий отблеск.</p><p>Связь этого явления непосредственно с природой короны достоверно не установлена.</p><p>После прекращения контакта эффект не сохранился.</p></div></section>
        <section class="artifact-feature-section" aria-labelledby="galdvin-observations-title"><div class="artifact-feature-section-head"><p class="eyebrow">VI / Предел наблюдений</p><h2 id="galdvin-observations-title">Известные свойства</h2></div><div class="artifact-feature-properties">${observations.map(([label, value], index) => `<article><span aria-hidden="true">0${index + 1}</span><h3>${esc(label)}</h3><p>${esc(value)}</p></article>`).join('')}</div></section>
        <section class="artifact-feature-section artifact-galdvin-unknown" aria-labelledby="galdvin-unknown-title"><div class="artifact-feature-section-head"><p class="eyebrow">VII / Неустановленные сведения</p><h2 id="galdvin-unknown-title">Что неизвестно</h2></div><div class="artifact-feature-prose"><p>Архив не располагает достоверными данными о:</p><ul>${unknown.map(value => `<li>${esc(value)}</li>`).join('')}</ul></div></section>
        <figure class="artifact-feature-owner artifact-galdvin-owner"><a href="images/galdvin.png" target="_blank" rel="noopener" aria-label="Открыть изображение короля Галдвина в полном размере"><img src="images/galdvin.png" alt="Король Галдвин без короны" width="998" height="1576" loading="lazy"></a><figcaption><span>Известный владелец</span><strong>Король Галдвин</strong><a href="Galdvin.html">Досье: король Галдвин ↗</a></figcaption><p>Король Галдвин — известный владелец реликвии и правитель Майзервина.</p><p>Именно связь артефакта с Галдвином представляет наибольший интерес для Архива: после смерти короля контакт с короной позволил Дариусу на мгновение ощутить отголосок его состояния.</p><p class="artifact-galdvin-owner__caption">Король Галдвин. Изображений правителя с короной в распоряжении Архива нет.</p></figure>
        <aside class="artifact-feature-note artifact-galdvin-note" aria-labelledby="galdvin-note-title"><p class="eyebrow">Архивная заметка</p><h2 id="galdvin-note-title">Неполное досье</h2><p>Корона короля Галдвина остаётся одним из наименее изученных артефактов Майзервина.</p><p>Архив располагает свидетельствами её воздействия, но практически не располагает сведениями о природе самого предмета.</p><p>Даже внешний вид реликвии не был достоверно зафиксирован.</p><p><strong>До получения новых сведений любые попытки восстановить её облик или объяснить механизм действия будут считаться предположением.</strong></p></aside>
        <div class="artifact-feature-end">${back}<a href="Tom_I.html">Перейти к Тому I ↗</a></div>
      </div>
    </article>`;
  }
  async function init() {
    try {
      const account = await TODMArchive.account();
      if (!account.session || !TODMArchive.can(account.access, entry.level)) {
        TODMArchive.gate(root, entry.level === 1 ? 'I' : '0', account, location.pathname.split('/').pop());
        root.insertAdjacentHTML('beforeend', `<div class="artifact-gate-back">${back}</div>`);
        return;
      }
      // The browser receives dossier text only after archive_content RLS approves this row.
      const { data, error } = await TODMAuth.client.from('archive_content')
        .select('id,body').eq('slug', entry.slug).maybeSingle();
      if (error) throw error;
      if (!data?.body) {
        root.innerHTML = `<section class="archive-gate"><h1>Запись ещё не активирована</h1><p>Досье ожидает применения миграции Supabase.</p>${back}</section>`;
        return;
      }
      const body = data.body;
      if (entry.tone === 'will') {
        renderWill();
      } else if (entry.tone === 'harvest') {
        renderHarvest();
      } else if (entry.tone === 'dragons') {
        renderDragons();
      } else if (entry.tone === 'wishes') {
        renderWishes();
      } else if (entry.tone === 'elements') {
        renderElements();
      } else if (entry.tone === 'frauster') {
        renderFrausterCrown();
      } else if (entry.tone === 'galdvin') {
        renderGaldvinCrown();
      } else {
      root.innerHTML = `<article class="artifact-dossier artifact-dossier--${entry.tone}"><header class="artifact-dossier__header"><nav class="artifact-breadcrumbs" aria-label="Путь к досье"><a href="Tom_I.html">Том I</a><span>→</span><a href="Artifacts_Tom_I.html">Артефакты</a><span>→</span><span>${esc(body.title)}</span></nav><p class="eyebrow">Досье ${entry.code} · ${entry.level ? 'Архив I' : 'Том I'}</p><h1>${esc(body.title)}</h1><p class="artifact-dossier__lead">${esc(body.summary)}</p>${back}</header><div class="artifact-dossier__content"><figure class="artifact-dossier__visual">${entry.image ? `<img src="${entry.image}" alt="${esc(body.title)}" loading="eager">` : `<div aria-hidden="true" class="artifact-dossier__plate"><span>${entry.code}</span><strong>${esc(body.title)}</strong></div>`}<figcaption>${entry.image ? 'Архивное изображение' : 'Иллюстрация артефакта пока не представлена в Архиве'}</figcaption></figure><div class="artifact-dossier__text"><dl class="artifact-facts"><div><dt>Тип</dt><dd>${esc(body.type)}</dd></div><div><dt>Связь</dt><dd>${esc(body.owner)}</dd></div><div><dt>Статус</dt><dd>${esc(body.status || 'Известен по Тому I')}</dd></div></dl><section><h2>Описание</h2>${paragraphs(body.description)}</section><section><h2>Известные свойства</h2><ul>${(body.properties || []).map(value => `<li>${esc(value)}</li>`).join('')}</ul></section>${body.origin?.length ? `<section><h2>Происхождение и свидетельства</h2>${paragraphs(body.origin)}</section>` : ''}${body.note ? `<aside class="artifact-dossier__note"><p class="eyebrow">Примечание Архива</p><p>${esc(body.note)}</p></aside>` : ''}${back}</div></div></article>`;
      }
      const read = await TODMAuth.client.from('content_reads').upsert({
        user_id: account.user.id, content_id: data.id, last_opened_at: new Date().toISOString()
      }, { onConflict: 'user_id,content_id' });
      if (read.error) console.warn('Artifact reading marker unavailable', read.error);
    } catch (error) {
      console.error(error);
      root.innerHTML = `<section class="archive-gate"><h1>Архив временно недоступен</h1><p>Не удалось загрузить досье.</p>${back}</section>`;
    }
  }
  init();
})();
