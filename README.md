<p align="center">
  <img src="assets/icons/app_icon.png" width="108" height="108" alt="Seriolab Icon" style="border-radius: 24px;" />
</p>

<h1 align="center">Seriolab</h1>

<p align="center">
  <strong>A tua aplicação minimalista e social de tracking de séries de televisão e anime.</strong>
</p>

<p align="center">
  <a href="https://github.com/TheMoita/seriolab/releases/latest">
    <img src="https://img.shields.io/github/v/release/TheMoita/seriolab?color=7C5CFC&label=Release&logo=github" alt="Latest Release" />
  </a>
  <img src="https://img.shields.io/badge/Platform-Android-38BDF8?logo=android&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Built%20with-Flutter%20%26%20Dart-02569B?logo=flutter&logoColor=white" alt="Built with Flutter" />
  <img src="https://img.shields.io/badge/License-MIT-10B981" alt="License" />
</p>

---

## 🧪 Sobre o Seriolab

O **Seriolab** é uma experiência cinematográfica e minimalista criada para maratonistas, cinéfilos de televisão e fãs de anime. Inspirado na estética e simplicidade de plataformas como o Letterboxd, o Seriolab combina o catálogo da televisão mundial com ferramentas sociais completas, gestão detalhada de episódios vistos e estatísticas visuais.

---

## ✨ Principais Funcionalidades

- **🎬 Catálogo Completo & TMDB:**
  - Sinopses, dados de produção, elencos detalhados e trailers oficiais do YouTube transmitidos diretamente na app sem anúncios.
  - Informações sempre atualizadas sobre temporadas, episódios e datas de exibição.

- **⏱️ Registo de Visualizações & Atividade Recente:**
  - Marcação ágil por episódio ou em lote por temporada inteira.
  - Histórico cronológico de atividade recente com ordenação precisa por data de visualização, temporada e episódio.

- **⭐️ Classificações & Top 5 Favoritos:**
  - Avaliações granulares de 0.5 a 10 estrelas para cada série ou episódio.
  - Gráfico visual da distribuição de notas (*Ratings Breakdown*).
  - Seleção em destaque das tuas **TOP 5** séries favoritas personalizável no perfil.

- **👥 Comunidade & Perfis Sociais:**
  - Perfis públicos com fotos de avatar, banners personalizados e biografias.
  - Sistema de seguidores (*Following* / *Followers*).
  - Críticas e notas por episódio com marcação de **Spoilers**, comentários da comunidade e sistema de moderação/denúncias.

- **🗓️ Agenda Inteligente:**
  - **A Ver Atualmente:** Apenas as séries ativas na tua biblioteca que têm episódios transmitidos pendentes por ver.
  - **Brevemente:** Novas estreias e próximas temporadas das séries que segues ou tens na tua Watchlist.

- **🔬 Identidade Visual Única:**
  - Tema noturno imersivo (*Midnight Indigo & Electric Violet* - `#0D0F17` e `#7C5CFC`).
  - Indicador de carregamento animado em vetor e puxar-para-atualizar personalizados com o copo de laboratório do Seriolab.

---

## 📲 Guia Passo a Passo de Instalação (Android)

Para utilizadores normais instalarem o Seriolab diretamente no telemóvel Android através do ficheiro APK:

1. **Aceder às Releases:**
   - Abre o link direto da [Última Release do Seriolab no GitHub](https://github.com/TheMoita/seriolab/releases/latest).

2. **Descarregar o APK:**
   - Na secção **Assets** da release, clica no ficheiro com o nome `seriolab-vX.X.X.apk` para iniciar a transferência.

3. **Autorizar Fontes Desconhecidas:**
   - Após terminar a transferência, clica na notificação do download ou acede à pasta *Downloads* no teu Gestor de Ficheiros.
   - Ao abrir o ficheiro `.apk`, caso o Android solicite permissão, ativa **"Instalar aplicações de fontes desconhecidas"** (ou *"Permitir a partir desta fonte"*) para o teu navegador ou gestor de ficheiros.

4. **Instalar e Abrir:**
   - Clica em **Instalar**. Assim que a instalação terminar, clica em **Abrir** e entra com a tua conta para começar a maratonar!

---

## 🔄 Como Atualizar a Aplicação

O Seriolab inclui um sistema integrado de verificação de atualizações (**In-App Update Checker**):

- **Verificação Automática:** Ao abrir a aplicação, serás discretamente notificado caso exista uma nova versão disponível no GitHub, podendo descarregá-la com um simples toque em **"Atualizar Agora"**.
- **Verificação Manual:** Acede a **Perfil** ➔ **Definições (ícone de engrenagem)** ➔ **Sobre & Versão** e clica em **"Verificar Atualizações"**.
- **Atualização Direta:** Podes sempre descarregar o APK mais recente a partir da página de [Releases](https://github.com/TheMoita/seriolab/releases/latest) e instalá-lo diretamente por cima da versão existente. **Não precisas de desinstalar a aplicação anterior** — as tuas séries guardadas, conta e configurações são 100% preservadas.

---

## 🛠️ Tecnologias Utilizadas

- **[Flutter](https://flutter.dev/) & [Dart](https://dart.dev/):** Framework multiplataforma de alta performance.
- **[Flutter Riverpod](https://riverpod.dev/):** Gestão de estado reativa, previsível e desacoplada.
- **[Firebase Authentication](https://firebase.google.com/products/auth) & [Cloud Firestore](https://firebase.google.com/products/firestore):** Sincronização em nuvem em tempo real e autenticação segura.
- **[SQLite (sqflite)](https://pub.dev/packages/sqflite):** Persistência e cache local offline ultrarrápida.
- **[The Movie Database (TMDB) API](https://www.themoviedb.org/documentation/api):** Catálogo global de séries de televisão, posters em alta resolução e metadados.
- **[GitHub Actions](https://github.com/features/actions):** Pipeline de integração e entrega contínua (CI/CD) para compilação e publicação automática de releases APK.

---

## 🛡️ Privacidade e Dados

- O Seriolab foi desenhado a pensar na privacidade: sem rastreamento de dados de navegação para publicidade de terceiros nem anúncios intrusivos.
- Os teus dados de progresso e séries podem ser sincronizados na nuvem ou exportados a qualquer momento em formato JSON e CSV através das Definições.

---

## 📄 Licença & Reconhecimentos

- Este projeto está sob a licença [MIT](LICENSE).
- Este produto utiliza a API do TMDB, mas não é endossado nem certificado pelo TMDB.
