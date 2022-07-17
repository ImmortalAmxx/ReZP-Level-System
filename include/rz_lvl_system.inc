/**
    * 	Получить урвоень игрока.
    *
    *   @param pPlayer      Игрок.
    *
    *   @return             integer
*/
native rz_get_user_level(pPlayer);

/**
    * 	Получить опыт игрока.
    *
    *   @param pPlayer      Игрок.
    *
    *   @return             integer
*/
native  rz_get_user_exp(pPlayer);

/**
    * 	Получить нужное количество опыта для следующего уровня.
    *
    *   @param pPlayer      Игрок.
    *
    *   @return             integer
*/
native  rz_get_user_next_exp(pPlayer);

/**
    * 	Установить нужное количество уровней для игрока.
    *
    *   @param pPlayer      Игрок.
    *   @param iNum      	Количество.
    *
    *   @return             
*/
native  rz_set_user_level(pPlayer, iNum);

/**
    * 	Установить нужное количество опыта для игрока.
    *
    *   @param pPlayer      Игрок.
    *   @param iNum      	Количество.
    *
    *   @return             
*/
native rz_set_user_exp(pPlayer, iNum);