
#ifndef __TREEMAP_H__
#define __TREEMAP_H__

typedef struct TreeMapNode
{
    const char *key;
    void *value;
    struct TreeMapNode *lesser, *greater, *parent;
} TreeMapNode;

typedef struct TreeMap
{
    TreeMapNode *root;
} TreeMap;

TreeMap *TreeMap_new();
void TreeMap_set(TreeMap *map, const char *key, void *value);
void *TreeMap_get(TreeMap *map, const char *key);
void TreeMap_del(TreeMap *map, const char *key);

#endif
