extends Node
## Global olay yolu. SADECE sinyal icerir, mantik icermez.
## Sozlesme degisikligi (yeni sinyal) once konusulur, sonra Berkay (A) gunceller.
## Autoload adi: EventBus (class_name KULLANMA, autoload ile cakisir).

## Para degisti. Tick basina degil, deger degistiginde atilir.
@warning_ignore("unused_signal")
signal currency_changed(amount: BigNumber)

## Saniyelik gelir degisti (orbiter alindi, upgrade alindi vb.).
@warning_ignore("unused_signal")
signal income_changed(per_sec: BigNumber)

## Bir orbiter turunun sayisi degisti.
@warning_ignore("unused_signal")
signal orbiter_count_changed(id: StringName, count: int)

## Bir upgrade satin alindi.
@warning_ignore("unused_signal")
signal upgrade_purchased(id: StringName)
