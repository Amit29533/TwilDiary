import { sampleDiary } from '../../src/lib/preview/fixtures.ts';

export const referenceOrigin = 'http://127.0.0.1:5193';
export const referenceTime = '2026-10-23T12:00:00.000Z';
export function referenceWorkspace() {
  const value = sampleDiary();
  for (const [index, event] of value.events.entries()) {
    event.watchedAt = index === 0 ? null : `2026-10-${String(23 - (index % 20)).padStart(2, '0')}T12:00:00.000Z`;
  }
  value.titles.find(t => t.id === 'frieren').score = 9.5;
  value.titles.find(t => t.id === 'again').score = 7.5;
  value.titles.find(t => t.id === 'quiet-orbit').queued = true;
  return value;
}

export const catalog = Array.from({length: 24}, (_, index) => ({
  id: 900001 + index, mediaType: index % 3 === 0 ? 'movie' : 'tv',
  name: ['The Clockmaker', 'A Quiet Journey', 'Midnight Stories', 'Beyond the Stars', 'The Last Summer', 'Letters Home'][index % 6] + (index > 5 ? ` ${index + 1}` : ''),
  year: 2020 + index % 7, overview: 'Fictional provider data used only for repeatable native parity verification.',
  posterPath: '/reference_poster.jpg', backdropPath: '/reference_backdrop.jpg',
  rating: 7.3 + index % 6 / 10, votes: 100 + index, genres: ['Drama', index % 2 ? 'Romance' : 'Animation'],
  source: 'tmdb', inLibraryId: null
}));

export function providerResponse(url, scenario = 'default') {
  const path = url.pathname;
  const unavailable = {error: {code: 'fixture_unavailable', message: 'The connection is temporarily unavailable. Try again.'}};
  if (scenario === 'provider-error' && ['/api/discovery', '/api/metadata/browse', '/api/metadata/person'].includes(path)) return {status: 503, body: unavailable};
  if (path === '/api/metadata/status') return {body: {connected: true}};
  if (path === '/api/metadata/cast') return {body: {cast: Array.from({length: 8}, (_,i)=>({id:700001+i,name:`Reference Actor ${i+1}`,character:`Character ${i+1}`,profilePath:'/reference_poster.jpg'})), stale:false}};
  if (path === '/api/metadata/related') return {body: {items: catalog.slice(0, 12), stale:false}};
  if (path === '/api/metadata/person') return {body: {person: {
    id:700001,name:'Reference Actor',biography:'A fictional biography for repeatable layout, disclosure and filmography verification. '.repeat(4),
    birthday:'1990-05-01',deathday:null,birthplace:'Reference City',department:'Acting',profilePath:'/reference_poster.jpg',aliases:['Reference Name'],
    credits:catalog.map((item,i)=>({...item,character:`Character ${i+1}`,job:'',popularity:100-i,episodeCount:item.mediaType==='tv'?12:null}))
  }, stale:false}};
  if (path === '/api/discovery') return {body: {items:scenario==='provider-empty'?[]:catalog.filter(t=>t.mediaType===(url.searchParams.get('type')??'tv')).slice(0,12),page:Number(url.searchParams.get('page')??1),totalPages:2}};
  if (path === '/api/discovery/seeds') return {body: {items:catalog.slice(0,5)}};
  if (path === '/api/metadata/search') return {body: {items:catalog.slice(0,5),page:1,totalPages:1}};
  if (path === '/api/metadata/browse' || path === '/api/metadata/title') {
    const movie = url.searchParams.get('type') === 'movie';
    const details = {...catalog[0],id:Number(url.searchParams.get('id')??900001),mediaType:movie?'movie':'tv',
      communityScore:8.4,runtimeMinutes:movie?112:24,imdbId:'tt9999001',suggestedCategory:movie?'movie':'anime',
      seasons:movie?[]:[{number:1,name:'Season 1',expectedEpisodes:12},{number:2,name:'Season 2',expectedEpisodes:12}]};
    return {body:path==='/api/metadata/title'?details:{details,libraryTitle:null}};
  }
  if (path === '/api/metadata/season') return {body: {items:Array.from({length:12},(_,i)=>({number:i+1,tmdbId:100+i,name:url.searchParams.get('reveal')==='1'?`Chapter ${i+1}`:'',overview:'Reference episode summary.',airedOn:'2024-01-01',stillPath:url.searchParams.get('reveal')==='1'?'/reference_backdrop.jpg':null,communityScore:8.1}))}};
  if (path === '/api/library/ratings') return {body: {source:'trakt',items:{}}};
  if (path === '/api/search') return {body: {items:[],nextCursor:null}};
  if (path === '/api/trakt/status') return {body: {configured:true,connected:scenario.startsWith('trakt-'),username:scenario.startsWith('trakt-')?'reference-user':null,lastSyncAt:null,needsReconnect:scenario==='trakt-expired'}};
  if (path === '/api/trakt/sync') {
    const connected = scenario.startsWith('trakt-');
    const state = scenario==='trakt-scanning'?'building':'review';
    return {body: {run:connected?{id:'reference-sync',state,stage:'history',page:1,progress:120,ratingMode:'round',error:null,retryAfter:0}:null,
      items:connected?catalog.slice(0,8).map((item,i)=>({id:`change-${i}`,kind:['history','rating','watchlist'][i%3],direction:i===2?'conflict':i%2?'push':'pull',name:item.name,detail:i%2?'Send to Trakt':'Import from Trakt',review:i===2,state:'pending',error:null,blocked:false,context:{local:'7.5',remote:'8',season:1,episode:3}})):[],
      counts:connected?{pending:8,links:0,failed:0,uncertain:0}:{},next:null}};
  }
  return null;
}
