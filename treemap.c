
#include "treemap.h"

#include <stdlib.h>
#include <string.h>

#define STRGT(x, y) strcmp(x, y) > 0
#define STRLT(x, y) strcmp(x, y) < 0
#define STREQ(x, y) strcmp(x, y) == 0

TreeMap *TreeMap_new()
{
    TreeMap *map = malloc(sizeof(TreeMap));
    map->root = NULL;
    return map;
}

void TreeMapNode_set(TreeMapNode *node, const char *key, void *value)
{
    if (STRGT(key, node->key) && !node->greater)
    {
        TreeMapNode *new_node = malloc(sizeof(TreeMapNode));
        new_node->key = key;
        new_node->value = value;
        new_node->lesser = NULL;
        new_node->greater = NULL;
        new_node->parent = node;
        node->greater = new_node;
    }
    else if (STRLT(key, node->key) && !node->lesser)
    {
        TreeMapNode *new_node = malloc(sizeof(TreeMapNode));
        new_node->key = key;
        new_node->value = value;
        new_node->lesser = NULL;
        new_node->greater = NULL;
        new_node->parent = node;
        node->lesser = new_node;
    }
    else if (STRGT(key, node->key))
        TreeMapNode_set(node->greater, key, value);
    else if (STRLT(key, node->key))
        TreeMapNode_set(node->lesser, key, value);
    else if (STREQ(key, node->key))
        node->value = value;
}

void TreeMap_set(TreeMap *map, const char *key, void *value)
{
    if (map->root == NULL)
    {
        TreeMapNode *node = malloc(sizeof(TreeMapNode));
        node->key = key;
        node->value = value;
        node->greater = NULL;
        node->lesser = NULL;
        node->parent = NULL;
        map->root = node;
    }
    else
        TreeMapNode_set(map->root, key, value);
}

void *TreeMapNode_get(TreeMapNode *node, const char *key)
{
    if (!node)
        return NULL;
    if (STREQ(node->key, key))
        return node->value;
    if (STRLT(key, node->key))
        return TreeMapNode_get(node->lesser, key);
    if (STRGT(key, node->key))
        return TreeMapNode_get(node->greater, key);
    return NULL;
}

void *TreeMap_get(TreeMap *map, const char *key)
{
    return TreeMapNode_get(map->root, key);
}

void TreeMapNode_del(TreeMap *map, TreeMapNode *node, const char *key)
{
    if (STRLT(key, node->key))
        TreeMapNode_del(map, node->lesser, key);
    else if (STRGT(key, node->key))
        TreeMapNode_del(map, node->greater, key);
    else
    {
        if (node->lesser && node->greater)
        {
            TreeMapNode *successor = node->greater;
            while (successor->lesser)
                successor = successor->lesser;
            node->key = successor->key;
            node->value = successor->value;
            if (successor == successor->parent->lesser)
                successor->parent->lesser = successor->greater;
            else
                successor->parent->greater = successor->greater;
            if (successor->greater)
                successor->greater->parent = successor->parent;
            free(successor);
        }
        else if (node->lesser)
        {
            if (node->parent == NULL)
                map->root = node->lesser;
            else if (node == node->parent->lesser)
                node->parent->lesser = node->lesser;
            else
                node->parent->greater = node->lesser;
            if (node->lesser)
                node->lesser->parent = node->parent;
            free(node);
        }
        else if (node->greater)
        {
            if (node->parent == NULL)
                map->root = node->greater;
            else if (node == node->parent->lesser)
                node->parent->lesser = node->greater;
            else
                node->parent->greater = node->greater;
            if (node->greater)
                node->greater->parent = node->parent;
            free(node);
        }
        else
        {
            if (node->parent == NULL)
                map->root = NULL;
            else if (node == node->parent->lesser)
                node->parent->lesser = NULL;
            else
                node->parent->greater = NULL;
            free(node);
        }
    }
}

void TreeMap_del(TreeMap *map, const char *key)
{
    if (map->root)
        TreeMapNode_del(map, map->root, key);
}