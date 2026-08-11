#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

T = {
    # Common/navigation
    "common.back_to_hub": ["Voltar ao Nó", "Back to the Knot", "Volver al Nudo"],
    "common.echo_archive": ["Arquivo de Ecos", "Echo Archive", "Archivo de Ecos"],
    "common.accessibility": ["Acessibilidade", "Accessibility", "Accesibilidad"],
    "common.journey": ["Jornada", "Journey", "Jornada"],
    "common.inventory": ["Inventário", "Inventory", "Inventario"],
    "common.paths": ["Veredas", "Paths", "Sendas"],
    "common.save": ["Salvar", "Save", "Guardar"],
    "common.settings": ["Ajustes", "Settings", "Ajustes"],

    # Journey setup
    "journey_setup.title": ["Preparar a Jornada", "Prepare the Journey", "Preparar la Jornada"],
    "journey_setup.intro": [
        "Escolha a Vereda, o Andarilho e as regras desta travessia. A dificuldade define o rigor da jornada sem alterar sua identidade.",
        "Choose the Path, the Wanderer, and the rules for this crossing. Difficulty sets the journey's rigor without changing its identity.",
        "Elige la Senda, el Caminante y las reglas de esta travesía. La dificultad define el rigor de la jornada sin cambiar su identidad."
    ],
    "journey_setup.route": ["Rota", "Route", "Ruta"],
    "journey_setup.wanderer": ["Andarilho", "Wanderer", "Caminante"],
    "journey_setup.mode": ["Modo", "Mode", "Modo"],
    "journey_setup.difficulty": ["Dificuldade", "Difficulty", "Dificultad"],
    "journey_setup.seed_help": [
        "Seed — deixe 0 para gerar automaticamente; Trama Compartilhada exige valor positivo",
        "Seed — leave 0 to generate automatically; Shared Weave requires a positive value",
        "Seed — deja 0 para generar automáticamente; Trama Compartida exige un valor positivo"
    ],
    "journey_setup.modifiers": ["Modificadores", "Modifiers", "Modificadores"],
    "journey_setup.start": ["Partir", "Set Out", "Partir"],
    "journey_setup.fixed_seed_required": [
        "Trama Compartilhada exige uma seed positiva para que a jornada possa ser repetida.",
        "Shared Weave requires a positive seed so the journey can be repeated.",
        "Trama Compartida exige una seed positiva para que la jornada pueda repetirse."
    ],
    "journey_setup.invalid": ["Configuração inválida: %s", "Invalid setup: %s", "Configuración inválida: %s"],
    "journey_setup.start_failed": ["Não foi possível iniciar esta jornada.", "This journey could not be started.", "No fue posible iniciar esta jornada."],

    # Codex
    "codex.category.world": ["Domínios", "Domains", "Dominios"],
    "codex.category.location": ["Localidades", "Locations", "Localidades"],
    "codex.category.character": ["Andarilhos", "Wanderers", "Caminantes"],
    "codex.category.monster": ["Monstros", "Monsters", "Monstruos"],
    "codex.category.boss": ["Chefes", "Bosses", "Jefes"],
    "codex.category.item": ["Itens", "Items", "Objetos"],
    "codex.category.npc": ["Pessoas", "People", "Personas"],
    "codex.category.mark": ["Marcas", "Marks", "Marcas"],
    "codex.category.debt": ["Dívidas Narrativas", "Narrative Debts", "Deudas Narrativas"],
    "codex.category.event": ["Situações", "Situations", "Situaciones"],
    "codex.category.ending": ["Finais", "Endings", "Finales"],
    "codex.category.ability": ["Habilidades", "Abilities", "Habilidades"],
    "codex.category.other": ["Outros", "Other", "Otros"],
    "codex.title": ["Arquivo de Ecos", "Echo Archive", "Archivo de Ecos"],
    "codex.subtitle": [
        "O Códice registra o que foi encontrado; não concede poder por completar listas.",
        "The Codex records what you have found; completing lists grants no power.",
        "El Códice registra lo que has encontrado; completar listas no concede poder."
    ],
    "codex.collection": ["[font_size=%d][b]Coleção[/b][/font_size]", "[font_size=%d][b]Collection[/b][/font_size]", "[font_size=%d][b]Colección[/b][/font_size]"],
    "codex.distinct_records": ["Registros distintos: [b]%d[/b]", "Distinct records: [b]%d[/b]", "Registros distintos: [b]%d[/b]"],
    "codex.achievements": ["[font_size=%d][b]Conquistas[/b][/font_size]", "[font_size=%d][b]Achievements[/b][/font_size]", "[font_size=%d][b]Logros[/b][/font_size]"],
    "codex.unlocked": ["Desbloqueadas: [b]%d / %d[/b]", "Unlocked: [b]%d / %d[/b]", "Desbloqueados: [b]%d / %d[/b]"],
    "codex.recent": ["[font_size=%d][b]Descobertas recentes[/b][/font_size]", "[font_size=%d][b]Recent discoveries[/b][/font_size]", "[font_size=%d][b]Descubrimientos recientes[/b][/font_size]"],
    "codex.empty": ["[i]As primeiras páginas ainda aguardam traços novos.[/i]", "[i]The first pages are still waiting for new marks.[/i]", "[i]Las primeras páginas aún esperan nuevos trazos.[/i]"],
    "codex.source.route": ["rota aberta", "route opened", "ruta abierta"],
    "codex.source.character": ["Andarilho liberado", "Wanderer unlocked", "Caminante desbloqueado"],
    "codex.source.legacy": ["registro anterior", "previous record", "registro anterior"],
    "codex.source.journey": ["jornada", "journey", "jornada"],

    # Hub
    "hub.title": ["Nó de Vigília", "Vigil Knot", "Nudo de Vigilia"],
    "hub.tagline": ["[font_size=%d][b]Um ponto estável entre Veredas instáveis.[/b][/font_size]", "[font_size=%d][b]A stable point between unstable Paths.[/b][/font_size]", "[font_size=%d][b]Un punto estable entre Sendas inestables.[/b][/font_size]"],
    "hub.stats.stage": ["Estágio do Nó: [b]%s/5[/b]   •   Visitas: %s   •   Residentes: %s", "Knot stage: [b]%s/5[/b]   •   Visits: %s   •   Residents: %s", "Etapa del Nudo: [b]%s/5[/b]   •   Visitas: %s   •   Residentes: %s"],
    "hub.stats.unlocks": ["Andarilhos: [b]%s/36[/b]   •   Rotas: [b]%s/12[/b]   •   Modos: [b]%s/4[/b]   •   Códice: [b]%s[/b]", "Wanderers: [b]%s/36[/b]   •   Routes: [b]%s/12[/b]   •   Modes: [b]%s/4[/b]   •   Codex: [b]%s[/b]", "Caminantes: [b]%s/36[/b]   •   Rutas: [b]%s/12[/b]   •   Modos: [b]%s/4[/b]   •   Códice: [b]%s[/b]"],
    "hub.stats.echoes": ["Conquistas: [b]%s/%s[/b]   •   Ecos persistentes: [b]%s[/b]   •   Consequências: [b]%s[/b]", "Achievements: [b]%s/%s[/b]   •   Persistent Echoes: [b]%s[/b]   •   Consequences: [b]%s[/b]", "Logros: [b]%s/%s[/b]   •   Ecos persistentes: [b]%s[/b]   •   Consecuencias: [b]%s[/b]"],
    "hub.stats.threads": ["Fios de Vigília: [b]%s[/b]   •   Gastos: %s   •   Aquisições: %s", "Vigil Threads: [b]%s[/b]   •   Spent: %s   •   Purchases: %s", "Hilos de Vigilia: [b]%s[/b]   •   Gastados: %s   •   Adquisiciones: %s"],
    "hub.facilities": ["[b]Instalações[/b]", "[b]Facilities[/b]", "[b]Instalaciones[/b]"],
    "hub.modes": ["[b]Formas de jornada conhecidas[/b]", "[b]Known journey forms[/b]", "[b]Formas de jornada conocidas[/b]"],
    "hub.residents": ["[b]Pessoas que encontraram abrigo no Nó[/b]", "[b]People who found shelter in the Knot[/b]", "[b]Personas que encontraron refugio en el Nudo[/b]"],
    "hub.continue": ["Continuar jornada", "Continue journey", "Continuar jornada"],
    "hub.abandon": ["Abandonar jornada e retornar ao Nó", "Abandon journey and return to the Knot", "Abandonar jornada y volver al Nudo"],
    "hub.prepare": ["Preparar jornada", "Prepare journey", "Preparar jornada"],
    "hub.examine_route": ["Examinar rota — %s", "Examine route — %s", "Examinar ruta — %s"],
    "hub.thread_table": ["Mesa dos Fios", "Thread Table", "Mesa de los Hilos"],
    "hub.route_detail": [
        "\n\n[i]A Mesa das Veredas conhece o caminho para %s. Andarilhos disponíveis nesta rota: %d. Use Preparar jornada para selecionar rota, Andarilho, modo, dificuldade, seed e modificadores.[/i]",
        "\n\n[i]The Path Table knows the way to %s. Wanderers available on this route: %d. Use Prepare journey to choose route, Wanderer, mode, difficulty, seed, and modifiers.[/i]",
        "\n\n[i]La Mesa de las Sendas conoce el camino hacia %s. Caminantes disponibles en esta ruta: %d. Usa Preparar jornada para elegir ruta, Caminante, modo, dificultad, seed y modificadores.[/i]"
    ],

    # Main journey
    "main.game_title": ["Veredas da Trama", "Veredas da Trama", "Veredas da Trama"],
    "main.unnamed_path": ["Uma Vereda sem nome", "An unnamed Path", "Una Senda sin nombre"],
    "main.story.none": ["[b]A Vereda silencia.[/b]\n\nNenhuma situação está disponível aqui agora. Viaje para outra localidade.", "[b]The Path falls silent.[/b]\n\nNo situation is available here right now. Travel to another location.", "[b]La Senda guarda silencio.[/b]\n\nNo hay ninguna situación disponible aquí ahora. Viaja a otra localidad."],
    "main.story.default_title": ["A Vereda aguarda", "The Path Awaits", "La Senda espera"],
    "main.story.choose": ["Escolher", "Choose", "Elegir"],
    "main.story.face_boss": ["Enfrentar a ameaça que domina este lugar", "Face the threat ruling this place", "Enfrentar la amenaza que domina este lugar"],
    "main.inventory.body": ["[font_size=%d][b]Inventário[/b][/font_size]\n\nItens carregados e equipamento atual.", "[font_size=%d][b]Inventory[/b][/font_size]\n\nCarried items and current equipment.", "[font_size=%d][b]Inventario[/b][/font_size]\n\nObjetos que llevas y equipo actual."],
    "main.inventory.empty": ["\n\nVocê ainda não carrega nenhum item.", "\n\nYou are not carrying any items yet.", "\n\nAún no llevas ningún objeto."],
    "main.inventory.equip": ["Equipar — %s", "Equip — %s", "Equipar — %s"],
    "main.inventory.use": ["Usar — %s", "Use — %s", "Usar — %s"],
    "main.back_to_journey": ["Voltar à jornada", "Back to the journey", "Volver a la jornada"],
    "main.merchant.body": ["[font_size=%d][b]Mercador da Vereda[/b][/font_size]\n\nFragmentos disponíveis: %s. O estoque muda conforme a jornada avança.", "[font_size=%d][b]Path Merchant[/b][/font_size]\n\nAvailable Fragments: %s. Stock changes as the journey advances.", "[font_size=%d][b]Mercader de la Senda[/b][/font_size]\n\nFragmentos disponibles: %s. El inventario cambia a medida que avanza la jornada."],
    "main.merchant.price": ["%s — %d Fragmentos", "%s — %d Fragments", "%s — %d Fragmentos"],
    "main.merchant.leave": ["Deixar o mercador", "Leave the merchant", "Dejar al mercader"],
    "main.travel.body": ["[font_size=%d][b]Veredas locais[/b][/font_size]\n\nEscolha a próxima localidade. Lugares já visitados permanecem registrados na jornada.", "[font_size=%d][b]Local Paths[/b][/font_size]\n\nChoose the next location. Places already visited remain recorded in the journey.", "[font_size=%d][b]Sendas locales[/b][/font_size]\n\nElige la próxima localidad. Los lugares ya visitados permanecen registrados en la jornada."],
    "main.travel.current": [" — atual", " — current", " — actual"],
    "main.combat.summary": ["[font_size=%d][b]%s[/b][/font_size]\n\nVida %s/%s • Postura %s/%s • Distância %s\n\n[b]Intenção:[/b] %s\n\nVocê: Vida %s/%s • Vigor %s/%s • Recurso %s", "[font_size=%d][b]%s[/b][/font_size]\n\nHealth %s/%s • Posture %s/%s • Distance %s\n\n[b]Intent:[/b] %s\n\nYou: Health %s/%s • Vigor %s/%s • Resource %s", "[font_size=%d][b]%s[/b][/font_size]\n\nSalud %s/%s • Postura %s/%s • Distancia %s\n\n[b]Intención:[/b] %s\n\nTú: Salud %s/%s • Vigor %s/%s • Recurso %s"],
    "main.combat.threat": ["Ameaça", "Threat", "Amenaza"],
    "main.combat.strike": ["Golpear", "Strike", "Golpear"],
    "main.combat.precise": ["Ataque preciso", "Precise attack", "Ataque preciso"],
    "main.combat.guard": ["Firmar guarda", "Brace guard", "Afirmar guardia"],
    "main.combat.advance": ["Avançar", "Advance", "Avanzar"],
    "main.combat.retreat": ["Recuar", "Retreat", "Retroceder"],
    "main.combat.ability": ["Habilidade", "Ability", "Habilidad"],
    "main.finals.body": ["[font_size=%d][b]Convergência local[/b][/font_size]\n\nA ameaça caiu, mas vencer não responde o que deve acontecer com este lugar. Escolha a consequência que sua jornada deixará.", "[font_size=%d][b]Local Convergence[/b][/font_size]\n\nThe threat has fallen, but victory does not answer what should happen to this place. Choose the consequence your journey will leave behind.", "[font_size=%d][b]Convergencia local[/b][/font_size]\n\nLa amenaza ha caído, pero vencer no responde qué debe ocurrir con este lugar. Elige la consecuencia que dejará tu jornada."],
    "main.finals.default": ["Desfecho", "Outcome", "Desenlace"],
    "main.debrief.body": ["[font_size=%d][b]Fim da jornada[/b][/font_size]\n\nResultado: %s\nDesfecho: %s\nBatidas: %s\nLocalidades visitadas: %s\nInimigos derrotados: %s\nCompras: %s\nMarcas: %s", "[font_size=%d][b]Journey's End[/b][/font_size]\n\nResult: %s\nOutcome: %s\nBeats: %s\nLocations visited: %s\nEnemies defeated: %s\nPurchases: %s\nMarks: %s", "[font_size=%d][b]Fin de la jornada[/b][/font_size]\n\nResultado: %s\nDesenlace: %s\nLatidos: %s\nLocalidades visitadas: %s\nEnemigos derrotados: %s\nCompras: %s\nMarcas: %s"],
    "main.debrief.restart": ["Iniciar outra jornada", "Start another journey", "Iniciar otra jornada"],
    "main.save_exit": ["\n\n[i]Jornada salva. Pressione Voltar novamente para sair.[/i]", "\n\n[i]Journey saved. Press Back again to exit.[/i]", "\n\n[i]Jornada guardada. Pulsa Atrás de nuevo para salir.[/i]"],

    # Vigil Threads
    "vigil.title": ["Fios de Vigília", "Vigil Threads", "Hilos de Vigilia"],
    "vigil.intro": ["Fios são recebidos uma única vez por marcos de descoberta. Eles compram conveniência e expressão no Nó — nunca dano, Vida, Vigor ou vantagem estatística.", "Threads are earned once for discovery milestones. They buy convenience and expression in the Knot — never damage, Health, Vigor, or statistical advantage.", "Los Hilos se reciben una sola vez por hitos de descubrimiento. Compran comodidad y expresión en el Nudo — nunca daño, Salud, Vigor ni ventaja estadística."],
    "vigil.balance": ["Saldo: [b]%d %s[/b]", "Balance: [b]%d %s[/b]", "Saldo: [b]%d %s[/b]"],
    "vigil.currency": ["Fios de Vigília", "Vigil Threads", "Hilos de Vigilia"],
    "vigil.lifetime": ["Recebidos ao longo do perfil: %d   •   Gastos: %d", "Earned across profile: %d   •   Spent: %d", "Recibidos en el perfil: %d   •   Gastados: %d"],
    "vigil.markers": ["Marcadores de jornada: %d   •   Seeds lembradas: %d   •   Fitas do Códice: %d", "Journey markers: %d   •   Remembered seeds: %d   •   Codex ribbons: %d", "Marcadores de jornada: %d   •   Seeds recordadas: %d   •   Cintas del Códice: %d"],
    "vigil.ornament_selected": ["Ornamento selecionado: %s", "Selected ornament: %s", "Ornamento seleccionado: %s"],
    "vigil.reward": ["+%d Fios recebidos por novos marcos desde a última visita.", "+%d Threads earned for new milestones since your last visit.", "+%d Hilos recibidos por nuevos hitos desde la última visita."],
    "vigil.no_reward": ["Nenhum marco novo aguardava recompensa. Repetir a mesma descoberta não gera Fios extras.", "No new milestone was waiting for a reward. Repeating the same discovery grants no extra Threads.", "Ningún hito nuevo esperaba recompensa. Repetir el mismo descubrimiento no concede Hilos extra."],
    "vigil.owned": ["Adquirido", "Owned", "Adquirido"],
    "vigil.price": ["%d Fios", "%d Threads", "%d Hilos"],
    "vigil.purchase_success": ["Aquisição registrada. Nenhum atributo de combate foi alterado.", "Purchase recorded. No combat attribute was changed.", "Adquisición registrada. Ningún atributo de combate fue alterado."],
    "vigil.purchase_unavailable": ["Essa aquisição ainda não está disponível ou faltam Fios.", "This purchase is not available yet or you do not have enough Threads.", "Esta adquisición aún no está disponible o faltan Hilos."],
    "vigil.ornament.ink": ["Moldura de Nanquim", "Ink Frame", "Marco de Tinta"],
    "vigil.ornament.echo": ["Selo de Eco", "Echo Seal", "Sello de Eco"],
    "vigil.ornament.plain": ["Papel simples", "Plain Paper", "Papel sencillo"],
}

FILES = {
    "scenes/JourneySetup.gd": {
        "Preparar a Jornada":"journey_setup.title",
        "Escolha a Vereda, o Andarilho e as regras desta travessia. Dificuldade é registrada agora; a calibração numérica final pertence à fase 10.6.":"journey_setup.intro",
        "Rota":"journey_setup.route", "Andarilho":"journey_setup.wanderer", "Modo":"journey_setup.mode", "Dificuldade":"journey_setup.difficulty",
        "Seed — deixe 0 para gerar automaticamente; Trama Compartilhada exige valor positivo":"journey_setup.seed_help",
        "Modificadores":"journey_setup.modifiers", "Partir":"journey_setup.start", "Voltar ao Nó":"common.back_to_hub",
        "Trama Compartilhada exige uma seed positiva para que a jornada possa ser repetida.":"journey_setup.fixed_seed_required",
        "Configuração inválida: %s":"journey_setup.invalid", "Não foi possível iniciar esta jornada.":"journey_setup.start_failed",
    },
    "scenes/VigilThreads.gd": {
        "Fios de Vigília":"vigil.title", "Fios são recebidos uma única vez por marcos de descoberta. Eles compram conveniência e expressão no Nó — nunca dano, Vida, Vigor ou vantagem estatística.":"vigil.intro",
        "Voltar ao Nó":"common.back_to_hub", "Saldo: [b]%d %s[/b]":"vigil.balance",
        "Recebidos ao longo do perfil: %d   •   Gastos: %d":"vigil.lifetime",
        "Marcadores de jornada: %d   •   Seeds lembradas: %d   •   Fitas do Códice: %d":"vigil.markers",
        "Ornamento selecionado: %s":"vigil.ornament_selected", "+%d Fios recebidos por novos marcos desde a última visita.":"vigil.reward",
        "Nenhum marco novo aguardava recompensa. Repetir a mesma descoberta não gera Fios extras.":"vigil.no_reward",
        "Adquirido":"vigil.owned", "%d Fios":"vigil.price", "Aquisição registrada. Nenhum atributo de combate foi alterado.":"vigil.purchase_success",
        "Essa aquisição ainda não está disponível ou faltam Fios.":"vigil.purchase_unavailable",
        "Moldura de Nanquim":"vigil.ornament.ink", "Selo de Eco":"vigil.ornament.echo", "Papel simples":"vigil.ornament.plain",
    },
    "scenes/Hub.gd": {
        "Nó de Vigília":"hub.title", "[font_size=%d][b]Um ponto estável entre Veredas instáveis.[/b][/font_size]":"hub.tagline",
        "Estágio do Nó: [b]%s/5[/b]   •   Visitas: %s   •   Residentes: %s":"hub.stats.stage",
        "Andarilhos: [b]%s/36[/b]   •   Rotas: [b]%s/12[/b]   •   Modos: [b]%s/4[/b]   •   Códice: [b]%s[/b]":"hub.stats.unlocks",
        "Conquistas: [b]%s/%s[/b]   •   Ecos persistentes: [b]%s[/b]   •   Consequências: [b]%s[/b]":"hub.stats.echoes",
        "Fios de Vigília: [b]%s[/b]   •   Gastos: %s   •   Aquisições: %s":"hub.stats.threads",
        "[b]Instalações[/b]":"hub.facilities", "[b]Formas de jornada conhecidas[/b]":"hub.modes", "[b]Pessoas que encontraram abrigo no Nó[/b]":"hub.residents",
        "Continuar jornada":"hub.continue", "Abandonar jornada e retornar ao Nó":"hub.abandon", "Preparar jornada":"hub.prepare",
        "Examinar rota — %s":"hub.examine_route", "Arquivo de Ecos":"common.echo_archive", "Mesa dos Fios":"hub.thread_table", "Acessibilidade":"common.accessibility",
        "\n\n[i]A Mesa das Veredas conhece o caminho para %s. Andarilhos disponíveis nesta rota: %d. Use Preparar jornada para selecionar rota, Andarilho, modo, dificuldade, seed e modificadores.[/i]":"hub.route_detail",
    },
    "scenes/Main.gd": {
        "Jornada":"common.journey", "Inventário":"common.inventory", "Veredas":"common.paths", "Salvar":"common.save", "Ajustes":"common.settings",
        "Veredas da Trama":"main.game_title", "Uma Vereda sem nome":"main.unnamed_path",
        "[b]A Vereda silencia.[/b]\n\nNenhuma situação está disponível aqui agora. Viaje para outra localidade.":"main.story.none",
        "A Vereda aguarda":"main.story.default_title", "Escolher":"main.story.choose", "Enfrentar a ameaça que domina este lugar":"main.story.face_boss",
        "[font_size=%d][b]Inventário[/b][/font_size]\n\nItens carregados e equipamento atual.":"main.inventory.body", "\n\nVocê ainda não carrega nenhum item.":"main.inventory.empty",
        "Equipar — %s":"main.inventory.equip", "Usar — %s":"main.inventory.use", "Voltar à jornada":"main.back_to_journey",
        "[font_size=%d][b]Mercador da Vereda[/b][/font_size]\n\nFragmentos disponíveis: %s. O estoque muda conforme a jornada avança.":"main.merchant.body",
        "%s — %d Fragmentos":"main.merchant.price", "Deixar o mercador":"main.merchant.leave",
        "[font_size=%d][b]Veredas locais[/b][/font_size]\n\nEscolha a próxima localidade. Lugares já visitados permanecem registrados na jornada.":"main.travel.body", " — atual":"main.travel.current",
        "[font_size=%d][b]%s[/b][/font_size]\n\nVida %s/%s • Postura %s/%s • Distância %s\n\n[b]Intenção:[/b] %s\n\nVocê: Vida %s/%s • Vigor %s/%s • Recurso %s":"main.combat.summary",
        "Ameaça":"main.combat.threat", "Golpear":"main.combat.strike", "Ataque preciso":"main.combat.precise", "Firmar guarda":"main.combat.guard", "Avançar":"main.combat.advance", "Recuar":"main.combat.retreat", "Habilidade":"main.combat.ability",
        "[font_size=%d][b]Convergência local[/b][/font_size]\n\nA ameaça caiu, mas vencer não responde o que deve acontecer com este lugar. Escolha a consequência que sua jornada deixará.":"main.finals.body",
        "Desfecho":"main.finals.default", "[font_size=%d][b]Fim da jornada[/b][/font_size]\n\nResultado: %s\nDesfecho: %s\nBatidas: %s\nLocalidades visitadas: %s\nInimigos derrotados: %s\nCompras: %s\nMarcas: %s":"main.debrief.body",
        "Iniciar outra jornada":"main.debrief.restart", "\n\n[i]Jornada salva. Pressione Voltar novamente para sair.[/i]":"main.save_exit",
    },
}

CODEX_CATEGORY_KEYS = {
    "world":"codex.category.world", "location":"codex.category.location", "character":"codex.category.character",
    "monster":"codex.category.monster", "boss":"codex.category.boss", "item":"codex.category.item",
    "npc":"codex.category.npc", "mark":"codex.category.mark", "debt":"codex.category.debt",
    "event":"codex.category.event", "ending":"codex.category.ending", "ability":"codex.category.ability", "other":"codex.category.other",
}
CODEX_FILE_LITERALS = {
    "Arquivo de Ecos":"codex.title", "O Códice registra o que foi encontrado; não concede poder por completar listas.":"codex.subtitle",
    "Voltar ao Nó":"common.back_to_hub", "[font_size=%d][b]Coleção[/b][/font_size]":"codex.collection",
    "Registros distintos: [b]%d[/b]":"codex.distinct_records", "[font_size=%d][b]Conquistas[/b][/font_size]":"codex.achievements",
    "Desbloqueadas: [b]%d / %d[/b]":"codex.unlocked", "[font_size=%d][b]Descobertas recentes[/b][/font_size]":"codex.recent",
    "[i]As primeiras páginas ainda aguardam traços novos.[/i]":"codex.empty", "rota aberta":"codex.source.route",
    "Andarilho liberado":"codex.source.character", "registro anterior":"codex.source.legacy",
}


def gd_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def add_localizer(text: str) -> str:
    anchor = "extends Control\n"
    if "var localization := LocalizationService.new()" not in text:
        if anchor not in text:
            raise RuntimeError("extends Control anchor missing")
        text = text.replace(anchor, anchor + "\nvar localization := LocalizationService.new()\n", 1)
    return text


def replace_literal(text: str, literal: str, key: str, path: str) -> str:
    token = gd_string(literal)
    if token not in text:
        raise RuntimeError(f"missing literal in {path}: {literal!r}")
    return text.replace(token, f'localization.text("{key}")')


def patch_codex(text: str) -> str:
    text = add_localizer(text)
    start = text.index("const CATEGORY_NAMES := {")
    end = text.index("}\n\nvar codex", start) + 2
    block = "const CATEGORY_NAMES := {\n" + "".join(
        f'    {gd_string(category)}:{gd_string(key)},\n' for category, key in CODEX_CATEGORY_KEYS.items()
    ) + "}"
    text = text[:start] + block + text[end:]
    for literal, key in CODEX_FILE_LITERALS.items():
        text = replace_literal(text, literal, key, "scenes/Codex.gd")
    old = '        var label := str(CATEGORY_NAMES.get(category, category))'
    new = '        var label := _category_name(str(category))'
    if old not in text: raise RuntimeError("codex category summary anchor missing")
    text = text.replace(old, new, 1)
    old = '            var name := str(record.get("name", content_id))\n            var category := str(CATEGORY_NAMES.get(str(entry.get("category", "other")), entry.get("category", "other")))'
    new = '            var record_view := localization.localize_record(record)\n            var name := str(record_view.get("name", content_id))\n            var category := _category_name(str(entry.get("category", "other")))'
    if old not in text: raise RuntimeError("codex recent anchor missing")
    text = text.replace(old, new, 1)
    old = '        _: return "jornada"\n\nfunc _date_suffix'
    new = '        _: return localization.text("codex.source.journey")\n\nfunc _category_name(category: String) -> String:\n    var key := str(CATEGORY_NAMES.get(category, "codex.category.other"))\n    return localization.text(key)\n\nfunc _date_suffix'
    if old not in text: raise RuntimeError("codex source/default anchor missing")
    text = text.replace(old, new, 1)
    return text


def patch_dynamic(rel: str, text: str) -> str:
    if rel == "scenes/JourneySetup.gd":
        text = text.replace('        route_option.add_item(str(world.get("name", world_id)))', '        var world_view := localization.localize_record(world)\n        route_option.add_item(str(world_view.get("name", world_id)))')
        text = text.replace('        character_option.add_item(str(character.get("name", character_id)))', '        var character_view := localization.localize_record(character)\n        character_option.add_item(str(character_view.get("name", character_id)))')
    elif rel == "scenes/VigilThreads.gd":
        text = text.replace('lines.append(localization.text("vigil.balance") % [int(summary.balance), summary.currency])', 'lines.append(localization.text("vigil.balance") % [int(summary.balance), localization.text("vigil.currency")])')
    elif rel == "scenes/Hub.gd":
        text = text.replace('            var npc: Dictionary = ContentRegistry.get_record(npc_id)\n            lines.append("• %s" % npc.get("name", npc_id))', '            var npc: Dictionary = ContentRegistry.get_record(npc_id)\n            var npc_view := localization.localize_record(npc)\n            lines.append("• %s" % npc_view.get("name", npc_id))')
        text = text.replace('            var world: Dictionary = ContentRegistry.get_record(world_id)\n            _button(localization.text("hub.examine_route") % world.get("name", world_id)', '            var world: Dictionary = ContentRegistry.get_record(world_id)\n            var world_view := localization.localize_record(world)\n            _button(localization.text("hub.examine_route") % world_view.get("name", world_id)')
        text = text.replace('    var world: Dictionary = ContentRegistry.get_record(world_id)\n    var characters: Array = MetaUnlockEngine.unlocked_characters(world_id)\n    summary.append_text(localization.text("hub.route_detail") % [world.get("name", world_id), characters.size()])', '    var world: Dictionary = ContentRegistry.get_record(world_id)\n    var world_view := localization.localize_record(world)\n    var characters: Array = MetaUnlockEngine.unlocked_characters(world_id)\n    summary.append_text(localization.text("hub.route_detail") % [world_view.get("name", world_id), characters.size()])')
    elif rel == "scenes/Main.gd":
        text = text.replace('    header.text = str(world.get("name", localization.text("main.game_title")))\n    location_label.text = str(location.get("name", localization.text("main.unnamed_path")))', '    var world_view := localization.localize_record(world)\n    var location_view := localization.localize_record(location)\n    header.text = str(world_view.get("name", localization.text("main.game_title")))\n    location_label.text = str(location_view.get("name", localization.text("main.unnamed_path")))')
        old = '    var title_size := AccessibilityService.font_size(25)\n    story.text = "[font_size=%d][b]%s[/b][/font_size]\\n\\n%s" % [title_size, current_event.get("title",localization.text("main.story.default_title")), current_event.get("text","")]\n    var available := EventDirector.available_choices(current_event)'
        new = '    var title_size := AccessibilityService.font_size(25)\n    var event_view := localization.localize_record(current_event)\n    story.text = "[font_size=%d][b]%s[/b][/font_size]\\n\\n%s" % [title_size, event_view.get("title",localization.text("main.story.default_title")), event_view.get("text","")]\n    var localized_choices: Array = event_view.get("choices", []) as Array\n    var available := EventDirector.available_choices(current_event)'
        if old in text:
            text = text.replace(old, new, 1)
        text = text.replace('        var choice: Dictionary = entry.get("choice",{})\n        _add_action_button(str(choice.get("text",localization.text("main.story.choose")))', '        var choice: Dictionary = entry.get("choice",{})\n        var display_choice: Dictionary = (localized_choices[idx] as Dictionary) if idx >= 0 and idx < localized_choices.size() else choice\n        _add_action_button(str(display_choice.get("text",localization.text("main.story.choose")))')
        text = text.replace('        var item := ContentRegistry.get_record(str(item_id))\n        var count := InventoryEngine.count_item(str(item_id))\n        var label := "%s%s" % [AffixEngine.display_name(item)', '        var item := ContentRegistry.get_record(str(item_id))\n        var item_view := localization.localize_record(item)\n        var count := InventoryEngine.count_item(str(item_id))\n        var label := "%s%s" % [AffixEngine.display_name(item_view)')
        text = text.replace('        var label := localization.text("main.merchant.price") % [AffixEngine.display_name(item), cost]', '        var item_view := localization.localize_record(item)\n        var label := localization.text("main.merchant.price") % [AffixEngine.display_name(item_view), cost]')
        text = text.replace('        var loc := ContentRegistry.get_record(str(location_id))\n        var suffix :=', '        var loc := ContentRegistry.get_record(str(location_id))\n        var loc_view := localization.localize_record(loc)\n        var suffix :=')
        text = text.replace('[loc.get("name",location_id), suffix]', '[loc_view.get("name",location_id), suffix]')
        text = text.replace('        var label := "★ %s — %d %s" % [ability.get("name",localization.text("main.combat.ability")), cost, ability.get("resource","")]', '        var ability_view := localization.localize_record(ability)\n        var resource_label := localization.label("resource", str(ability.get("resource", "")))\n        var label := "★ %s — %d %s" % [ability_view.get("name",localization.text("main.combat.ability")), cost, resource_label]')
        text = text.replace('        var ending_id := str(ending.get("id",""))\n        _add_action_button(str(ending.get("name",localization.text("main.finals.default")))', '        var ending_id := str(ending.get("id",""))\n        var ending_view := localization.localize_record(ending)\n        _add_action_button(str(ending_view.get("name",localization.text("main.finals.default")))')
        text = text.replace('    var ending := ContentRegistry.get_record(str(report.get("ending_id","")))\n    story.text = localization.text("main.debrief.body") % [AccessibilityService.font_size(25), report.get("result",""), ending.get("name","—")', '    var ending := ContentRegistry.get_record(str(report.get("ending_id","")))\n    var ending_view := localization.localize_record(ending)\n    story.text = localization.text("main.debrief.body") % [AccessibilityService.font_size(25), report.get("result",""), ending_view.get("name","—")')
    return text


def update_catalogs() -> None:
    manifest_path = ROOT / "localization" / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    required = [str(v) for v in manifest.get("ui_required_keys", [])]
    for key in T:
        if key not in required:
            required.append(key)
    manifest["ui_required_keys"] = required
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    locales = ["pt_BR", "en", "es_419"]
    for idx, locale in enumerate(locales):
        path = ROOT / "localization" / "ui" / f"{locale}.json"
        catalog = json.loads(path.read_text(encoding="utf-8"))
        for key, values in T.items():
            catalog[key] = values[idx]
        path.write_text(json.dumps(dict(sorted(catalog.items())), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    update_catalogs()
    for rel, mapping in FILES.items():
        path = ROOT / rel
        text = add_localizer(path.read_text(encoding="utf-8"))
        for literal, key in mapping.items():
            text = replace_literal(text, literal, key, rel)
        text = patch_dynamic(rel, text)
        path.write_text(text, encoding="utf-8")

    codex_path = ROOT / "scenes" / "Codex.gd"
    codex_path.write_text(patch_codex(codex_path.read_text(encoding="utf-8")), encoding="utf-8")
    print("UI_LOCALIZATION_MIGRATION PASS: scenes=5 translated_keys=%d" % len(T))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
