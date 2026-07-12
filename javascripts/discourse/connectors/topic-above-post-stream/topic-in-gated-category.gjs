import TopicInGatedCategory from "../../components/topic-in-gated-category";

<template>
  <TopicInGatedCategory
    @categoryId={{@outletArgs.model.category_id}}
    @tags={{@outletArgs.model.tags}}
  />
</template>
